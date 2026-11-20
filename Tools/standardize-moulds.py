#!/usr/bin/env python3
"""
Standardizes all six sculpted cassette mould assets onto the canonical
OneTapeCassetteStandard coordinate frame (576 x 376.33 pt at 3x = 1728 x 1129 px),
locking both supply & takeup reel axles to (171.81, 172.32) and (403.93, 172.32),
uniform drive core radius 29.0 pt (58.0 pt diameter), and collar radius 38.5 pt (77.0 pt diameter).
"""
import argparse, json, math, os
import numpy as np
import cv2

S = 3.0
OUT_W, OUT_H = 1728, 1129          # 576 x 376.33 pt at 3x
PREV_W, PREV_H = 1152, 753         # 576 x 376.33 pt at 2x
FRAME = (13.3333, 13.3333, 549.3333, 349.6667)

T0 = np.array([171.81, 172.32])    # standard supply landscape axle (pt)
T1 = np.array([403.93, 172.32])    # standard takeup landscape axle (pt)
HUB_R = 29.0                       # standard drive radius (pt) -> 58.0 pt dia
COL_R = 38.5                       # standard collar radius (pt) -> 77.0 pt dia
SHAFT_R = 9.0                      # standard center shaft asset radius (pt) -> 54x54 px @ 3x

OUTLINES = {
    "strata":  (53, 44, 1492 - 53, 955 - 44),
    "facet":   (47, 77, 1492 - 47, 955 - 77),
    "islands": (42, 68, 1452, 886),
    "ribs":    (28, 42, 1475, 939),
    "stream":  (30, 40, 1503, 930),
    "eclipse": (52, 59, 1439, 916),
}

def exact_shaft_center(arr_gray, cx, cy):
    sub = arr_gray[cy - 28:cy + 28, cx - 28:cx + 28]
    sy, sx = np.where(sub > 150)
    if len(sx) > 10:
        return np.array([cx - 28 + (sx.min() + sx.max()) / 2.0,
                         cy - 28 + (sy.min() + sy.max()) / 2.0])
    return np.array([float(cx), float(cy)])

def measure_well_and_groove(arr_gray, center, design_id):
    cx, cy = center
    rs = np.arange(48.0, 122.0, 0.5)
    ang = np.linspace(0.0, 2.0 * np.pi, 144, endpoint=False)
    prof = []
    for r in rs:
        xs = np.clip((cx + r * np.cos(ang)).astype(int), 0, arr_gray.shape[1] - 1)
        ys = np.clip((cy + r * np.sin(ang)).astype(int), 0, arr_gray.shape[0] - 1)
        prof.append(arr_gray[ys, xs].mean())
    prof = np.array(prof)
    well_candidates = np.where((rs >= 52.0) & (rs <= 88.0) & (prof >= 122.0))[0]
    well_r = float(rs[well_candidates[0]])
    max_g = 112.0 if design_id == "stream" else 118.0
    g_mask = (rs >= well_r + 14.0) & (rs <= max_g)
    g_rs = rs[g_mask]
    groove_r = float(g_rs[np.argmin(prof[g_mask])])
    return well_r, groove_r

def src_to_pt(pt_xy, d_outline):
    ox, oy, ow, oh = d_outline
    return np.array([FRAME[0] + (pt_xy[0] - ox) * (FRAME[2] / ow),
                     FRAME[1] + (pt_xy[1] - oy) * (FRAME[3] / oh)])

def smooth_tps_solve(anchors_dst, anchors_src):
    n = len(anchors_dst)
    K = np.zeros((n + 3, n + 3), dtype=np.float64)
    for i in range(n):
        for j in range(n):
            if i == j:
                K[i, j] = 1e-4
            else:
                r2 = np.sum((anchors_dst[i] - anchors_dst[j]) ** 2)
                K[i, j] = r2 * math.log(r2 + 1e-6)
        K[i, n] = 1.0; K[i, n + 1] = anchors_dst[i, 0]; K[i, n + 2] = anchors_dst[i, 1]
        K[n, i] = 1.0; K[n + 1, i] = anchors_dst[i, 0]; K[n + 2, i] = anchors_dst[i, 1]
    rhs_x = np.zeros(n + 3); rhs_x[:n] = anchors_src[:, 0] - anchors_dst[:, 0]
    rhs_y = np.zeros(n + 3); rhs_y[:n] = anchors_src[:, 1] - anchors_dst[:, 1]
    wx = np.linalg.solve(K, rhs_x)
    wy = np.linalg.solve(K, rhs_y)
    return wx, wy

def eval_tps(px, py, anchors_dst, wx, wy):
    n = len(anchors_dst)
    dx_res = np.full_like(px, wx[n] + wx[n + 1] * px + wx[n + 2] * py, dtype=np.float64)
    dy_res = np.full_like(py, wy[n] + wy[n + 1] * px + wy[n + 2] * py, dtype=np.float64)
    for i in range(n):
        r2 = (px - anchors_dst[i, 0]) ** 2 + (py - anchors_dst[i, 1]) ** 2
        phi = np.where(r2 > 1e-8, r2 * np.log(r2 + 1e-8), 0.0)
        dx_res += wx[i] * phi
        dy_res += wy[i] * phi
    return px + dx_res, py + dy_res

def process_design(d):
    did = d["id"]
    src_img = cv2.imread(d["path"], cv2.IMREAD_UNCHANGED)
    if src_img.shape[2] == 3:
        src_img = cv2.cvtColor(src_img, cv2.COLOR_BGR2BGRA)
    gray = cv2.cvtColor(src_img[:, :, :3], cv2.COLOR_BGR2GRAY)
    ol = OUTLINES[did]
    ox, oy, ow, oh = ol

    c0_px = exact_shaft_center(gray, d["centers"][0][0], d["centers"][0][1])
    c1_px = exact_shaft_center(gray, d["centers"][1][0], d["centers"][1][1])
    well0, groove0 = measure_well_and_groove(gray, c0_px, did)
    well1, groove1 = measure_well_and_groove(gray, c1_px, did)

    o0 = src_to_pt(c0_px, ol)
    o1 = src_to_pt(c1_px, ol)
    ht_pt = src_to_pt((ox, d["headTop"]), ol)[1]

    anchors_dst, anchors_src = [], []
    # Keep outer envelope & lower head bridge anchored stationary
    lock_pts = []
    for px in np.linspace(8, 568, 13):
        lock_pts.extend([(px, 8.0), (px, 368.0), (px, max(ht_pt - 2.0, 276.0)), (px, 328.0)])
    for py in np.linspace(45, 250, 6):
        lock_pts.extend([(10.0, py), (566.0, py), (38.0, py), (538.0, py)])
    for lx, ly in lock_pts:
        anchors_dst.append([lx, ly]); anchors_src.append([lx, ly])

    if did == "strata":
        # Lock top terrace shoulder cleanly across entire width including center 288
        for px in [95.0, 150.0, 215.0, 288.0, 361.0, 426.0, 481.0]:
            anchors_dst.append([px, 76.0]); anchors_src.append([px, 76.0])
        dy_mid = (o0[1] + o1[1]) * 0.5 - T0[1]
        for px in [150.0, 225.0, 288.0, 350.0, 426.0]:
            anchors_dst.append([px, 118.0]); anchors_src.append([px, 118.0 + dy_mid])
            anchors_dst.append([px, 224.0]); anchors_src.append([px, 224.0 + dy_mid])
        win_c = src_to_pt((d["slots"][0][0] + d["slots"][0][2] / 2.0,
                           d["slots"][0][1] + d["slots"][0][3] / 2.0), ol)
        win_t = np.array([(T0[0] + T1[0]) / 2.0, T0[1]])
        for wx_off in [-46.0, 0.0, 46.0]:
            for wy_off in [-22.0, 0.0, 22.0]:
                anchors_dst.append([win_t[0] + wx_off, win_t[1] + wy_off])
                anchors_src.append([win_c[0] + wx_off, win_c[1] + wy_off])
    elif did == "facet":
        win_c = src_to_pt((d["slots"][0][0] + d["slots"][0][2] / 2.0,
                           d["slots"][0][1] + d["slots"][0][3] / 2.0), ol)
        win_t = np.array([(T0[0] + T1[0]) / 2.0, T0[1]])
        for wx_off in [-36.0, 0.0, 36.0]:
            for wy_off in [-12.0, 0.0, 12.0]:
                anchors_dst.append([win_t[0] + wx_off, win_t[1] + wy_off])
                anchors_src.append([win_c[0] + wx_off, win_c[1] + wy_off])
    else:
        mid_src = np.array([(o0[0] + o1[0]) * 0.5, (o0[1] + o1[1]) * 0.5])
        anchors_dst.append([287.87, 172.32]); anchors_src.append(mid_src.tolist())

    for Ti, ci_px, col_r_px in [(T0, c0_px, groove0), (T1, c1_px, groove1)]:
        for k in range(16):
            ang = 2.0 * math.pi * k / 16.0
            dx_pt = Ti[0] + COL_R * math.cos(ang)
            dy_pt = Ti[1] + COL_R * math.sin(ang)
            sx_px = ci_px[0] + col_r_px * math.cos(ang)
            sy_px = ci_px[1] + col_r_px * math.sin(ang)
            s_pt = src_to_pt((sx_px, sy_px), ol)
            anchors_dst.append([dx_pt, dy_pt]); anchors_src.append([s_pt[0], s_pt[1]])
        ci_pt = src_to_pt(ci_px, ol)
        anchors_dst.append([Ti[0], Ti[1]]); anchors_src.append([ci_pt[0], ci_pt[1]])

    anchors_dst = np.array(anchors_dst, dtype=np.float64)
    anchors_src = np.array(anchors_src, dtype=np.float64)
    wx, wy = smooth_tps_solve(anchors_dst, anchors_src)

    gx = (np.arange(OUT_W, dtype=np.float64) + 0.5) / S
    gy = (np.arange(OUT_H, dtype=np.float64) + 0.5) / S
    X, Y = np.meshgrid(gx, gy)
    PX, PY = eval_tps(X, Y, anchors_dst, wx, wy)

    SX = ox + (PX - FRAME[0]) * (ow / FRAME[2])
    SY = oy + (PY - FRAME[1]) * (oh / FRAME[3])

    # Exact isotropic circular mapping inside both canonical collars [0..HUB_R] & [HUB_R..COL_R]
    for Ti, ci_px, well_px, groove_px in [
        (T0, c0_px, well0, groove0),
        (T1, c1_px, well1, groove1),
    ]:
        dx_t = X - Ti[0]
        dy_t = Y - Ti[1]
        r_t = np.hypot(dx_t, dy_t)
        mask_col = r_t <= COL_R + 0.5
        r_safe = np.maximum(r_t, 1e-6)
        r_src = np.where(
            r_t <= HUB_R,
            r_t * (well_px / HUB_R),
            well_px + (r_t - HUB_R) * ((groove_px - well_px) / (COL_R - HUB_R))
        )
        exact_sx = ci_px[0] + (dx_t / r_safe) * r_src
        exact_sy = ci_px[1] + (dy_t / r_safe) * r_src
        w_blend = np.clip((COL_R + 0.5 - r_t) / 1.0, 0.0, 1.0)
        SX = np.where(mask_col, exact_sx * w_blend + SX * (1.0 - w_blend), SX)
        SY = np.where(mask_col, exact_sy * w_blend + SY * (1.0 - w_blend), SY)

    shell_3x = cv2.remap(src_img, SX.astype(np.float32), SY.astype(np.float32),
                         interpolation=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE)
    preview_2x = cv2.resize(shell_3x, (PREV_W, PREV_H), interpolation=cv2.INTER_AREA)

    # Extract standardized circular Drive0/Drive1 (58pt dia -> 174x174 px @ 3x) & Shaft0/Shaft1 (18pt dia -> 54x54 px @ 3x)
    drives, shafts = [], []
    drive_size = int(round(HUB_R * 2 * S))   # 174
    shaft_size = int(round(SHAFT_R * 2 * S)) # 54
    for Ti, ci_px, well_px in [(T0, c0_px, well0), (T1, c1_px, well1)]:
        # Resample source drive cleanly onto canonical 174x174 (r = HUB_R = 29pt)
        dgx = (np.arange(drive_size, dtype=np.float64) + 0.5) / S - HUB_R
        dgy = (np.arange(drive_size, dtype=np.float64) + 0.5) / S - HUB_R
        DX, DY = np.meshgrid(dgx, dgy)
        DSX = ci_px[0] + DX * (well_px / HUB_R)
        DSY = ci_px[1] + DY * (well_px / HUB_R)
        drv = cv2.remap(src_img, DSX.astype(np.float32), DSY.astype(np.float32),
                        interpolation=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE)
        drives.append(drv)

        # Extract shaft pin at proportional scale
        sgx = (np.arange(shaft_size, dtype=np.float64) + 0.5) / S - SHAFT_R
        sgy = (np.arange(shaft_size, dtype=np.float64) + 0.5) / S - SHAFT_R
        SGX, SGY = np.meshgrid(sgx, sgy)
        SSX = ci_px[0] + SGX * (well_px / HUB_R)
        SSY = ci_px[1] + SGY * (well_px / HUB_R)
        shf = cv2.remap(src_img, SSX.astype(np.float32), SSY.astype(np.float32),
                        interpolation=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE)
        shafts.append(shf)

    # Forward-estimate canonical positions of any slots (strata/facet/etc.) by finding inverse warp root or transforming slot corners
    # Compute forward map on sparse grid to map source pt -> canonical pt
    mapped_slots = []
    if d["slots"]:
        fwd_pt = []
        # Newton solve PX(x,y)=tx, PY(x,y)=ty for corners of each slot
        for sx, sy, sw, sh in d["slots"]:
            t0 = src_to_pt((sx, sy), ol)
            t1 = src_to_pt((sx + sw, sy + sh), ol)
            pts_src = [t0, t1]
            res = []
            for target_pt in pts_src:
                p = np.array([target_pt[0], target_pt[1]], dtype=np.float64)
                for _ in range(8):
                    cur_x, cur_y = eval_tps(np.array([p[0]]), np.array([p[1]]), anchors_dst, wx, wy)
                    p[0] += (target_pt[0] - cur_x[0]) * 0.8
                    p[1] += (target_pt[1] - cur_y[0]) * 0.8
                res.append(p)
            mapped_slots.append([round(float(res[0][0]), 2), round(float(res[0][1]), 2),
                                 round(float(res[1][0] - res[0][0]), 2), round(float(res[1][1] - res[0][1]), 2)])

    return {
        "id": did,
        "shell": shell_3x,
        "preview": preview_2x,
        "drives": drives,
        "shafts": shafts,
        "well0": well0, "groove0": groove0,
        "well1": well1, "groove1": groove1,
        "mapped_slots": mapped_slots,
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Write standardized assets into Assets.xcassets")
    parser.add_argument("--scratch-dir", default="/Users/liuhang/.gemini/antigravity/brain/86b36a78-fb35-4330-b78d-b49f59ad3b5f/scratch")
    args = parser.parse_args()

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    cfg = json.load(open(os.path.join(root, "Evidence/0.4.0/approved-print-friendly-moulds-20261108/production-inputs.json")))

    tiles = []
    for d in cfg["designs"]:
        res = process_design(d)
        did = res["id"]
        print(f"{did:8s}: wells=({res['well0']},{res['well1']}) grooves=({res['groove0']},{res['groove1']}) canonical_slots={res['mapped_slots']}")

        if args.apply:
            suffix = did[0].upper() + did[1:]
            base = f"OneTapeMould{suffix}Closed"
            assets_root = os.path.join(root, "Stillroom/Resources/Assets.xcassets")
            cv2.imwrite(os.path.join(assets_root, f"{base}.imageset/{base}.png"), res["shell"])
            cv2.imwrite(os.path.join(assets_root, f"{base}Preview.imageset/{base}Preview.png"), res["preview"])
            for idx in range(2):
                cv2.imwrite(os.path.join(assets_root, f"{base}Drive{idx}.imageset/{base}Drive{idx}.png"), res["drives"][idx])
                cv2.imwrite(os.path.join(assets_root, f"{base}Shaft{idx}.imageset/{base}Shaft{idx}.png"), res["shafts"][idx])

        dbg = res["shell"].copy()
        for (tx, ty) in [T0, T1]:
            cx_o, cy_o = int(round(tx * S)), int(round(ty * S))
            cv2.circle(dbg, (cx_o, cy_o), int(round(HUB_R * S)), (0, 255, 255, 255), 2)
            cv2.circle(dbg, (cx_o, cy_o), int(round(COL_R * S)), (0, 0, 255, 255), 2)
            cv2.drawMarker(dbg, (cx_o, cy_o), (0, 255, 0, 255), cv2.MARKER_CROSS, 20, 2)
        tiles.append(cv2.resize(dbg, (576, 376)))

    sheet = np.vstack([np.hstack(tiles[:3]), np.hstack(tiles[3:])])
    os.makedirs(args.scratch_dir, exist_ok=True)
    cv2.imwrite(os.path.join(args.scratch_dir, "moulds_std_v2.png"), sheet)
    print("Wrote verification sheet to", os.path.join(args.scratch_dir, "moulds_std_v2.png"))

if __name__ == "__main__":
    main()

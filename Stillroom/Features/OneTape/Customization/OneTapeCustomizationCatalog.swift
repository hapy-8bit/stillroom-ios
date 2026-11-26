import SwiftUI

extension OneTapeAppearance.DoodleStyle {
    var customizationTitle: String {
        OneTapeDoodleCatalog.title(for: self)
    }

    var customizationThumbnailAsset: String {
        OneTapeDoodleCatalog.thumbnailAsset(for: self)
    }
}

extension OneTapeAppearance.BodyStyle {
    var customizationTitle: String {
        switch self {
        case .black: "黑色"
        case .graphite: "石墨"
        case .adaptive: "随曲配色"
        case .cover: "封面"
        }
    }

    var customizationThumbnailAsset: String {
        switch self {
        case .black: "OneTapeBodyBlackThumb"
        case .graphite: "OneTapeBodyGraphiteThumb"
        case .adaptive: "OneTapeBodyColourThumb"
        case .cover: "OneTapeBodyCoverThumb"
        }
    }
}

extension OneTapeAppearance.BodyColor {
    var customizationTitle: String {
        switch self {
        case .black: "黑色"
        case .navy: "藏蓝"
        case .green: "绿色"
        case .slate: "板岩灰"
        case .dove: "鸽灰"
        case .cognac: "干邑棕"
        case .white: "白色"
        case .garden: "花园"
        }
    }

}

extension OneTapeAppearance.ScreenStyle {
    var customizationTitle: String {
        switch self {
        case .lcd: "读数"
        case .fluid: "流体"
        case .oscilloscope: "示波"
        case .sand: "沙粒"
        case .dunes: "沙丘"
        case .meters: "电平"
        case .water: "水面"
        case .iron: "铁屑"
        case .name: "名称"
        case .cover: "封面"
        case .fox: "狐狸"
        case .ink: "墨滴"
        case .smoke: "烟雾"
        case .growth: "生长"
        case .harmonograph: "谐振摆"
        case .waterfall: "频谱瀑布"
        case .rain: "雨窗"
        case .trails: "轨迹"
        }
    }

    var customizationDescription: String {
        switch self {
        case .lcd: "LCD 像素显示曲目、时间、歌名与艺人。轻点播放器屏幕即可切换。"
        case .oscilloscope: "一条深墨单线直接描绘真实音频波形，如同实验室示波器。"
        case .fluid: "浅色反光面板上的黑色磁流体，随低音涌动、随底鼓分裂再聚拢。"
        case .sand: "克拉尼声学金属板上的细沙：随底鼓跳起，落成随乐曲变换的驻波图案。"
        case .dunes: "细沙随缓慢的风聚成沙脊移过面板，低音悄然改变风向。"
        case .meters: "与读数同款的 LCD 点阵十六段电平表，峰值缓缓回落。"
        case .water: "单色反光水面：每次底鼓是一滴水，低音是缓缓涌浪，高音是轻风。"
        case .iron: "铺在两颗磁铁上的黑色铁屑，磁极随低音漂移，底鼓震动纸面。"
        case .name: "当前歌曲与艺人用细沙写就，节拍将字母震散，再缓缓重新聚合。"
        case .cover: "当前专辑封面化作细沙点画，底鼓把沙粒震起，再落回画面。"
        case .fox: "戴着耳机的小狐狸，播放时随节拍律动，停下来十秒便安静打盹。"
        case .ink: "静水中的深墨水滴：每次底鼓落下一滴，圆环扩散、交叉并渐隐。"
        case .smoke: "空气中的墨烟：底鼓喷出烟团，人声将其搅动成缓慢涡流。"
        case .growth: "珊瑚与指纹背后的图灵反应扩散纹样，随音乐生长、分裂与愈合。"
        case .harmonograph: "双摆画笔在面板上绘出螺旋几何曲线，摆幅停下后重新起笔。"
        case .waterfall: "十六段电平历史逐行滑落，用 LCD 点阵铺开一幅声谱瀑布。"
        case .rain: "雨滴滑过烟青色玻璃，远处的光被温柔揉开。"
        case .trails: "细金光线沿曲折轨迹逐段生长，余辉缓缓消散。"
        }
    }

}

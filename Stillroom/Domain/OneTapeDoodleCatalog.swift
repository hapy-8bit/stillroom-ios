import Foundation

/// Built-in cassette illustration metadata and shell pairing rules recovered from
/// `TapeDoodle` (`1.0.3 / build 9` binary analysis + asset catalog).
enum OneTapeDoodleCatalog {
    struct Entry: Equatable, Sendable {
        let title: String
        let assetBase: String
    }

    static let sharedClassicStyles: [OneTapeAppearance.DoodleStyle] = [
        .climber, .smile, .bicycle, .cat, .fishing, .tightrope, .swing, .sleeper
    ]

    static let allOverStyles: [OneTapeAppearance.DoodleStyle] = [
        .creatures, .people, .shapes, .plants, .daydream, .faces,
        .littleMachines, .soundMaze, .circuitGarden, .orbitDoodles
    ]

    /// Returns whether a built-in illustration belongs to the given shell cutout,
    /// matching Cassette 1.0.5 `TapeDoodle.fits(skin:)` (`0x1002018c4`).
    static func supports(
        _ doodle: OneTapeAppearance.DoodleStyle,
        on tapeStyle: OneTapeAppearance.TapeStyle
    ) -> Bool {
        doodle == .none || supportedStyles(for: tapeStyle).contains(doodle)
    }

    /// Shell-specific illustration list matching Cassette 1.0.5 `TapeDoodle.available(for:)`
    /// (`0x100204d74`), aligned to each active shell's physical window silhouette so artwork
    /// frames the spools and aperture without awkward clipping.
    static func supportedStyles(for tapeStyle: OneTapeAppearance.TapeStyle) -> [OneTapeAppearance.DoodleStyle] {
        switch tapeStyle {
        case .classic, .graphite:
            return [.none, .dog, .caterpillar, .seesaw, .city, .wild] + sharedClassicStyles
        case .memphis:
            // Woven linen uses the classic shell geometry; match Cassette's solid `Tape` set.
            return [.none, .city, .wild] + sharedClassicStyles
        case .clear:
            return [.none, .ants, .peek, .snail, .pilgrims]
        case .window:
            return [.none, .napper, .cleaner, .theatre]
        case .bronze:
            // Exact Cassette 1.0.5 `MouldedBronzeWedge` pairing for the diagonal wedge cutout.
            return [.none, .megaphone, .cone, .spotlight, .lighthouse]
        case .armature:
            // Wide horizontal window pairing (`SmokeBand` + `OliveArch` silhouettes).
            return [.none, .aquarium, .cinema, .picturehouse, .bus, .boat, .sofa, .train]
        case .fieldNotes:
            // Pressed-rib waisted peanut aperture (`PaperRibbed` + `SunsetLabel` silhouettes).
            return [
                .none,
                .lifter, .hammock, .skipping, .circus,
                .sunglasses, .binoculars, .robot, .aviator
            ]
        case .silverOval:
            // Sleek horizontal capsule oval aperture (`SilverOval` + `WaistWindow` silhouettes).
            return [
                .none,
                .runners, .hotdog, .pool, .stadium,
                .submarine, .blimp, .dachshund, .zeppelin
            ]
        case .twinArc:
            // Figure-8 dual-arc aperture (`TwinArc` + dual-lens `PanelClear` silhouettes).
            return [.none, .headphones, .heart, .umbrella, .hills, .frog, .tandem, .diver]
        case .strata:
            return [.none, .megaphone, .cone, .spotlight, .lighthouse] + allOverStyles
        case .facet:
            return [.none] + allOverStyles
        case .islands:
            return [.none, .owl, .astronaut, .panda, .observatory] + allOverStyles
        case .ribs:
            return [.none, .frog, .tandem, .diver] + allOverStyles
        case .stream:
            return [.none, .skier, .sledge, .surfer, .chalet] + allOverStyles
        case .eclipse:
            return [.none, .runners, .hotdog, .pool, .stadium] + allOverStyles
        }
    }

    static func entry(for style: OneTapeAppearance.DoodleStyle) -> Entry {
        entries[style] ?? Entry(title: style.rawValue, assetBase: "")
    }

    static func title(for style: OneTapeAppearance.DoodleStyle) -> String {
        entry(for: style).title
    }

    static func thumbnailAsset(for style: OneTapeAppearance.DoodleStyle) -> String {
        switch style {
        case .none:
            return ""
        case .wild:
            return "OneTapeDoodleWildThumb"
        default:
            return "OneTapeDoodle\(entry(for: style).assetBase)Thumb"
        }
    }

    /// Ink mask asset on the cassette shell. The five early redrawn designs keep their
    /// `RecreatedInkV1` (1536×1024 landscape); `.littleMachines` uses the native bundled
    /// 1024×1536 portrait stencil; the other 74 use crisp landscape 1536×1024 illustrations.
    static func inkAsset(for style: OneTapeAppearance.DoodleStyle) -> (name: String, isPortraitTemplate: Bool)? {
        switch style {
        case .none: return nil
        case .dog: return ("OneTapeDoodleDogRecreatedInkV1", false)
        case .caterpillar: return ("OneTapeDoodleCaterpillarRecreatedInkV1", false)
        case .seesaw: return ("OneTapeDoodleSeesawRecreatedInkV1", false)
        case .city: return ("OneTapeDoodleCityRecreatedInkV1", false)
        case .wild: return ("OneTapeDoodleWildRecreatedInkV1", false)
        case .littleMachines: return ("OneTapeDoodleLittleMachinesInk", true)
        default:
            return ("OneTapeDoodle\(entry(for: style).assetBase)Ink", false)
        }
    }

    private static let entries: [OneTapeAppearance.DoodleStyle: Entry] = [
        .none: Entry(title: "无", assetBase: "None"),
        .climber: Entry(title: "攀岩者", assetBase: "Climber"),
        .smile: Entry(title: "微笑", assetBase: "Smile"),
        .bicycle: Entry(title: "自行车", assetBase: "Bicycle"),
        .cat: Entry(title: "猫咪", assetBase: "Cat"),
        .fishing: Entry(title: "钓鱼", assetBase: "Fishing"),
        .tightrope: Entry(title: "走钢丝", assetBase: "Tightrope"),
        .swing: Entry(title: "秋千", assetBase: "Swing"),
        .sleeper: Entry(title: "安睡", assetBase: "Sleeper"),
        .creatures: Entry(title: "小生灵", assetBase: "Creatures"),
        .people: Entry(title: "人物", assetBase: "People"),
        .shapes: Entry(title: "形状", assetBase: "Shapes"),
        .plants: Entry(title: "植物", assetBase: "Plants"),
        .daydream: Entry(title: "白日梦", assetBase: "Daydream"),
        .faces: Entry(title: "面孔", assetBase: "Faces"),
        .littleMachines: Entry(title: "小机器", assetBase: "LittleMachines"),
        .soundMaze: Entry(title: "迷宫", assetBase: "SoundMaze"),
        .circuitGarden: Entry(title: "电路板", assetBase: "CircuitGarden"),
        .orbitDoodles: Entry(title: "轨道", assetBase: "OrbitDoodles"),
        .dog: Entry(title: "小狗", assetBase: "Dog"),
        .ants: Entry(title: "蚂蚁", assetBase: "Ants"),
        .slide: Entry(title: "滑梯", assetBase: "Slide"),
        .megaphone: Entry(title: "扩音器", assetBase: "Megaphone"),
        .skier: Entry(title: "滑雪者", assetBase: "Skier"),
        .owl: Entry(title: "猫头鹰", assetBase: "Owl"),
        .bus: Entry(title: "巴士", assetBase: "Bus"),
        .lifter: Entry(title: "举重者", assetBase: "Lifter"),
        .runners: Entry(title: "跑者", assetBase: "Runners"),
        .aquarium: Entry(title: "水族箱", assetBase: "Aquarium"),
        .sunglasses: Entry(title: "太阳镜", assetBase: "Sunglasses"),
        .headphones: Entry(title: "耳机", assetBase: "Headphones"),
        .submarine: Entry(title: "潜水艇", assetBase: "Submarine"),
        .moon: Entry(title: "月亮", assetBase: "Moon"),
        .tv: Entry(title: "电视", assetBase: "Tv"),
        .cone: Entry(title: "圆锥", assetBase: "Cone"),
        .spotlight: Entry(title: "聚光灯", assetBase: "Spotlight"),
        .caterpillar: Entry(title: "毛毛虫", assetBase: "Caterpillar"),
        .seesaw: Entry(title: "跷跷板", assetBase: "Seesaw"),
        .peek: Entry(title: "探头", assetBase: "Peek"),
        .snail: Entry(title: "蜗牛", assetBase: "Snail"),
        .birds: Entry(title: "飞鸟", assetBase: "Birds"),
        .abseil: Entry(title: "绳降", assetBase: "Abseil"),
        .sledge: Entry(title: "雪橇", assetBase: "Sledge"),
        .surfer: Entry(title: "冲浪者", assetBase: "Surfer"),
        .astronaut: Entry(title: "宇航员", assetBase: "Astronaut"),
        .panda: Entry(title: "熊猫", assetBase: "Panda"),
        .boat: Entry(title: "小船", assetBase: "Boat"),
        .sofa: Entry(title: "沙发", assetBase: "Sofa"),
        .frog: Entry(title: "青蛙", assetBase: "Frog"),
        .tandem: Entry(title: "双人单车", assetBase: "Tandem"),
        .hammock: Entry(title: "吊床", assetBase: "Hammock"),
        .skipping: Entry(title: "跳绳", assetBase: "Skipping"),
        .hotdog: Entry(title: "热狗", assetBase: "Hotdog"),
        .pool: Entry(title: "泳池", assetBase: "Pool"),
        .cinema: Entry(title: "影院", assetBase: "Cinema"),
        .table: Entry(title: "桌子", assetBase: "Table"),
        .binoculars: Entry(title: "望远镜", assetBase: "Binoculars"),
        .robot: Entry(title: "机器人", assetBase: "Robot"),
        .heart: Entry(title: "爱心", assetBase: "Heart"),
        .umbrella: Entry(title: "雨伞", assetBase: "Umbrella"),
        .blimp: Entry(title: "飞艇", assetBase: "Blimp"),
        .dachshund: Entry(title: "腊肠犬", assetBase: "Dachshund"),
        .napper: Entry(title: "小憩", assetBase: "Napper"),
        .cleaner: Entry(title: "清洁工", assetBase: "Cleaner"),
        .mountain: Entry(title: "山峰", assetBase: "Mountain"),
        .lighthouse: Entry(title: "灯塔", assetBase: "Lighthouse"),
        .pilgrims: Entry(title: "旅人", assetBase: "Pilgrims"),
        .frame: Entry(title: "画框", assetBase: "Frame"),
        .chalet: Entry(title: "小木屋", assetBase: "Chalet"),
        .observatory: Entry(title: "天文台", assetBase: "Observatory"),
        .train: Entry(title: "火车", assetBase: "Train"),
        .diver: Entry(title: "潜水员", assetBase: "Diver"),
        .circus: Entry(title: "马戏团", assetBase: "Circus"),
        .stadium: Entry(title: "体育场", assetBase: "Stadium"),
        .picturehouse: Entry(title: "老影院", assetBase: "Picturehouse"),
        .aviator: Entry(title: "飞行员", assetBase: "Aviator"),
        .city: Entry(title: "城市", assetBase: "City"),
        .wild: Entry(title: "野生", assetBase: "Overgrown"),
        .hills: Entry(title: "山丘", assetBase: "Hills"),
        .zeppelin: Entry(title: "齐柏林飞艇", assetBase: "Zeppelin"),
        .theatre: Entry(title: "剧院", assetBase: "Theatre")
    ]
}

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
        case .fox: "狐狸"
        case .ink: "墨水"
        case .rain: "雨窗"
        case .trails: "轨迹"
        case .waterfall: "频谱瀑布"
        }
    }

    var customizationDescription: String {
        switch self {
        case .lcd: "像素时钟与曲目信息，留住熟悉的机械节奏。"
        case .fluid: "黑与烟灰的宽阔折流，在歌曲文字旁缓慢回转。"
        case .oscilloscope: "一条银白色的线，描绘此刻正在响起的声音。"
        case .sand: "细沙聚成纹样，在声音里松开，又重新相遇。"
        case .dunes: "侧光照亮沙脊与宽阔暗面，像掠过沙丘的慢风。"
        case .meters: "十六列细密光点，把音乐的高低起伏留下。"
        case .water: "青灰色水面、细碎反光与彼此交叠的涟漪。"
        case .iron: "细密的深色铁屑沿弧线聚拢，安静地舒展与收缩。"
        case .name: "曲名由细粒组成，字形边缘轻轻散聚；艺人、曲序与时间清晰留在一旁。"
        case .fox: "戴着耳机的小狐狸，播放时摇摆，停下来便打个盹。"
        case .ink: "一滴墨缓慢浸润纸面，留下层层轻柔的边缘。"
        case .rain: "雨滴滑过烟青色玻璃，远处的光被温柔揉开。"
        case .trails: "细金光线沿曲折轨迹逐段生长，余辉在深色留白中缓缓消散。"
        case .waterfall: "音乐的频谱逐行落下，像一幅不断展开的声纹。"
        }
    }

}

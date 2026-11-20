import SwiftUI

/// Local materials and normalized aperture geometry for the mechanical panel only.
enum MechanicalCardStyle {
    static let faceLight = Color(hex: 0x39393B)
    static let faceDark = Color(hex: 0x252527)
    static let recess = Color(hex: 0x161617)
    static let wheelCenter = Color(hex: 0xC7C6C2)
    static let wheelEdge = Color(hex: 0xB4B3AF)
    static let windowTop = Color(hex: 0x9B9A96)
    static let windowCenter = Color(hex: 0xCAC9C4)
    static let ink = Color(hex: 0x303032)
    static let text = Color(hex: 0xC7C5C1)
    static let cornerRadius: CGFloat = 22

    static func leftDepth(_ width: CGFloat) -> CGFloat { width * 0.105 }
    static func rightDepth(_ width: CGFloat) -> CGFloat { width * 0.17 }
}

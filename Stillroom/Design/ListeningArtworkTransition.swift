import SwiftUI

enum ListeningArtworkTransition {
    static let record = "listening.record"
    static func cover(_ track: Track) -> String { "listening.cover." + track.albumKey }

    static func animation(reducedMotion: Bool) -> Animation {
        reducedMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.82, dampingFraction: 0.9)
    }
}

private struct ListeningArtworkHero: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    @ViewBuilder func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    func listeningHero(_ id: String, in namespace: Namespace.ID?) -> some View {
        modifier(ListeningArtworkHero(id: id, namespace: namespace))
    }
}

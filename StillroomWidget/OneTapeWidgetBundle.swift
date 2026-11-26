import SwiftUI
import UIKit
import WidgetKit

struct OneTapeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: OneTapeWidgetSnapshot
    let artwork: UIImage?
}

struct OneTapeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OneTapeWidgetEntry {
        OneTapeWidgetEntry(date: Date(), snapshot: .empty, artwork: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OneTapeWidgetEntry) -> Void) {
        let now = Date()
        let snapshot = OneTapeWidgetSharedStore.shared.loadSnapshot().projected(at: now)
        let artwork = snapshot.artworkID.isEmpty ? nil : OneTapeWidgetSharedStore.shared.loadArtwork()
        completion(OneTapeWidgetEntry(date: now, snapshot: snapshot, artwork: artwork))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OneTapeWidgetEntry>) -> Void) {
        let now = Date()
        let current = OneTapeWidgetSharedStore.shared.loadSnapshot().projected(at: now)
        let artwork = current.artworkID.isEmpty ? nil : OneTapeWidgetSharedStore.shared.loadArtwork()
        let dates = current.timelineDates(from: now, maxEntries: 24)
        let entries = dates.map { date in
            OneTapeWidgetEntry(
                date: date,
                snapshot: current.projected(at: date),
                artwork: artwork
            )
        }
        let policy: TimelineReloadPolicy
        if current.isPlaying, let finalDate = dates.last, finalDate > now {
            policy = .after(finalDate)
        } else {
            policy = .never
        }
        completion(Timeline(entries: entries, policy: policy))
    }
}

struct OneTapeWidgetEntryView: View {
    let entry: OneTapeWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var widgetSize: OneTapeWidgetSize {
        switch family {
        case .systemSmall: .small
        case .systemMedium: .medium
        case .systemLarge: .large
        default: .small
        }
    }

    var body: some View {
        OneTapeWidgetCardView(
            snapshot: entry.snapshot,
            size: widgetSize,
            artwork: entry.artwork,
            controlsMode: .intents
        )
        .widgetURL(OneTapeWidgetConstants.deepLinkURL)
        .containerBackground(for: .widget) {
            OneTapeWidgetBackground(snapshot: entry.snapshot)
        }
    }
}

struct OneTapeCassetteWidget: Widget {
    let kind = OneTapeWidgetConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OneTapeWidgetProvider()) { entry in
            OneTapeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("One Cassette")
        .description("你的专辑，化作一盘真实的磁带。播放、切歌，看计数器转动。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct OneTapeWidgetBundle: WidgetBundle {
    var body: some Widget {
        OneTapeCassetteWidget()
    }
}

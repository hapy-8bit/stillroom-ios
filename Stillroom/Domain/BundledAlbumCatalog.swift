import Foundation

struct BundledAlbumCredit {
    let year: Int
    let albumPage: URL
    let audioSource: URL
    let artworkCredit: String?
    let license: URL
}

/// Nine real releases, each represented by one original recording. Existing reference and
/// legacy demo IDs retain their songs, so saved queues and crafted editions stay compatible.
enum BundledAlbumCatalog {
    static let tracks: [Track] = [
        Track(id: "cz-cylinder-one", title: "Cylinder One", artist: "Chris Zabriskie", album: "Cylinders",
              audioFile: "cz-cylinder-one.m4a", palette: .local, duration: 176.10666666666665,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-heliograph", title: "Heliograph", artist: "Chris Zabriskie", album: "Divider",
              audioFile: "cz-heliograph.m4a", palette: .local, duration: 339.47244897959183,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-angiesss", title: "11:11 at Smith – Ninth Streets", artist: "Chris Zabriskie", album: "Angie's Sunday Service",
              audioFile: "cz-angiesss.m4a", palette: .local, duration: 228.5220634920635,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-src", title: "She Can Live Without Me", artist: "Chris Zabriskie", album: "Soft Rock Champion",
              audioFile: "cz-src.m4a", palette: .local, duration: 110.42666666666666,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-ababab", title: "An Extraordinary Camera Was Custom Built and Used Only Once", artist: "Chris Zabriskie", album: "Abandon Babylon",
              audioFile: "cz-ababab.m4a", palette: .local, duration: 316.68866213151927,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-asleep", title: "I'm About to Do the Second Hardest Thing I've Ever Done", artist: "Chris Zabriskie", album: "I Made This While You Were Asleep",
              audioFile: "cz-asleep.m4a", palette: .local, duration: 400,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-neptuneflux", title: "Stories About the World That Once Was", artist: "Chris Zabriskie", album: "Music from Neptune Flux",
              audioFile: "cz-neptuneflux.m4a", palette: .local, duration: 414.6,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1),
        Track(id: "cz-reappear", title: "Is That You or Are You You?", artist: "Chris Zabriskie", album: "Reappear",
              audioFile: "cz-reappear.m4a", palette: .local, duration: 301.4878911564626,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 4),
        Track(id: "cz-dtv", title: "Direct to Video", artist: "Chris Zabriskie", album: "Direct to Video",
              audioFile: "cz-dtv.m4a", palette: .local, duration: 345.22179138321997,
              lyrics: "", isDemo: true, isLyricDemo: false, albumArtist: "Chris Zabriskie", trackNumber: 1)
    ]

    static func isReferenceID(_ id: String) -> Bool { tracks.contains { $0.id == id } }

    static func artworkAssetName(for id: String) -> String? {
        switch id {
        case "cz-cylinder-one": return "CylindersCover"
        case "cz-heliograph": return "DividerCover"
        case "cz-angiesss": return "AngiesSundayServiceCover"
        case "cz-src": return "SoftRockChampionCover"
        case "cz-ababab": return "AbandonBabylonCover"
        case "cz-asleep": return "IMadeThisWhileYouWereAsleepCover"
        case "cz-neptuneflux": return "MusicFromNeptuneFluxCover"
        case "cz-reappear": return "ReappearCover"
        case "cz-dtv": return "DirectToVideoCover"
        default: return nil
        }
    }

    static func credit(for id: String) -> BundledAlbumCredit? {
        guard let track = tracks.first(where: { $0.id == id }) else { return nil }
        let slug: String
        let year: Int
        let artworkCredit: String?
        switch id {
        case "cz-cylinder-one":
            slug = "cylinders"
            year = 2014
            artworkCredit = "Artwork by Patrick Scott Bell"
        case "cz-heliograph":
            slug = "divider"
            year = 2011
            artworkCredit = nil
        case "cz-angiesss":
            slug = "angiesss"
            year = 2022
            artworkCredit = "Artwork by Patrick Scott Bell"
        case "cz-src":
            slug = "src"
            year = 2022
            artworkCredit = nil
        case "cz-ababab":
            slug = "ababab"
            year = 2021
            artworkCredit = "Artwork by Patrick Scott Bell"
        case "cz-asleep":
            slug = "asleep"
            year = 2020
            artworkCredit = "Artwork by Patrick Scott Bell"
        case "cz-neptuneflux":
            slug = "neptuneflux"
            year = 2016
            artworkCredit = "Artwork by Patrick Scott Bell"
        case "cz-reappear":
            slug = "reappear"
            year = 2012
            artworkCredit = nil
        case "cz-dtv":
            slug = "dtv"
            year = 2015
            artworkCredit = "Artwork by Patrick Scott Bell"
        default: return nil
        }
        // The official player addresses the real 1-based track position; Reappear uses track4.
        let number = String(format: "%02d", track.trackNumber ?? 1)
        guard let page = URL(string: "https://chriszabriskie.com/" + slug + "/"),
              let audio = URL(string: "https://audio.chriszabriskie.com/" + slug + "/" + slug + "-" + number + ".m4a"),
              let license = URL(string: "https://creativecommons.org/licenses/by/4.0/") else { return nil }
        return BundledAlbumCredit(year: year, albumPage: page, audioSource: audio,
            artworkCredit: artworkCredit, license: license)
    }
}

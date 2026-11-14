import Foundation
import os

/// One feature of one release, as What's New shows it: the bullet of `CHANGELOG.md`, with the tag
/// the release author wrote at its end read into typed data (`WhatsNew+Parse.swift`).
public struct WhatsNewItem: Identifiable, Hashable, Sendable {

    /// Where the feature lives. A tagged bullet names a screen (`open=recordings`) or says it is a change
    /// across the app (`open=-`: the window, the sidebar); a bullet with no readable tag is `untagged`
    /// (every release before tags existed) and is grouped by its bold topic line instead.
    public enum Scope: Hashable, Sendable {
        case screen(String)
        case app
        case untagged
    }

    /// The version plus the bullet's position in its release: stable while the changelog is, and the route's payload.
    public let id: String
    /// "2.71.0"; nil for the unreleased section.
    public let version: String?
    public let released: Date?
    /// The release's title without its version: "Recording sources, one period menu…".
    public let releaseTitle: String
    /// The row's one line: the tag's title, or the bullet's first sentence.
    public let summary: String
    /// The title the tag gave, if it did (a name, in title style; `summary` is the first sentence otherwise).
    public let tagTitle: String?
    /// The whole bullet as prose, tag removed, Markdown as written.
    public let body: String
    public let scope: Scope
    /// An SF Symbol name from the tag.
    public let symbol: String?
    /// Reserved for a later version that shows a picture of the feature: read, kept, never shown yet.
    public let image: String?
    /// The bold line the bullet sat under: the fallback group of an untagged bullet.
    public let topic: String?
    /// True for the "Other Notes" row of a release: the paragraphs after its bullets, not a bullet.
    public let isNotes: Bool

    public init(id: String, version: String?, released: Date?, releaseTitle: String, summary: String, tagTitle: String?,
                body: String, scope: Scope, symbol: String?, image: String?, topic: String?, isNotes: Bool = false) {
        self.id = id; self.version = version; self.released = released; self.releaseTitle = releaseTitle
        self.summary = summary; self.tagTitle = tagTitle; self.body = body; self.scope = scope; self.symbol = symbol
        self.image = image; self.topic = topic; self.isNotes = isNotes
    }

    /// The deep-link target `Open <Screen>` goes to; nil for a change across the app and for an untagged bullet.
    public var target: String? {
        if case .screen(let target) = scope { target } else { nil }
    }
}

/// One release's What's New entry, from the changelog bundled with the app (the same
/// `CHANGELOG.md` each GitHub release publishes).
public struct ReleaseNote: Identifiable, Sendable {
    /// "v2.68.0 — See where all of your memory goes"
    public let title: String
    /// "2.68.0"; nil for the unreleased section.
    public let version: String?
    public let released: Date?
    /// The paragraphs before the first bullet: what the release is about.
    public let intro: [String]
    public let items: [WhatsNewItem]
    /// The paragraphs after the first bullet that are not topic lines: "Minor fixes and improvements throughout."
    public let closing: [String]

    public var id: String { title }
    public var isUnreleased: Bool { version == nil }

    /// The title without "v2.68.0 — ".
    public var releaseTitle: String {
        guard let version else { return title }
        let rest = title.dropFirst(version.count + 1).drop { $0 == " " || $0 == "—" || $0 == "-" || $0 == ":" }
        return String(rest)
    }

    /// The same release under another name on screen (the channels name the unreleased section differently).
    public func renamed(_ title: String) -> ReleaseNote {
        ReleaseNote(title: title, version: version, released: released, intro: intro,
                    items: items.map { $0.renamed(releaseTitle: title) }, closing: closing)
    }

    /// What the list shows for this release: its features, then one "Other Notes" row when the entry has paragraphs
    /// after its bullets (a "Fixed: …" note) that no feature carries, so nothing the old screen showed is lost.
    public var listedItems: [WhatsNewItem] { items + [notesItem].compactMap { $0 } }

    /// The feature-like row for `closing`; nil when there is none. Its screen shows the paragraphs.
    public var notesItem: WhatsNewItem? {
        guard !closing.isEmpty else { return nil }
        return WhatsNewItem(id: "\(version ?? "next")#notes", version: version, released: released, releaseTitle: releaseTitle,
                            summary: Names.WhatsNew.notesFor(version), tagTitle: nil, body: closing.joined(separator: "\n\n"),
                            scope: .untagged, symbol: "note.text", image: nil, topic: Names.WhatsNew.otherNotes, isNotes: true)
    }

    /// What the unreleased section is called on screen.
    public static let unreleasedTitle = "In This Build — Not Yet Released"

    /// Each "## vX.Y…" heading starts one release; newest first, as written.
    ///
    /// A build ahead of the last release (`includeNext`) starts with what is in
    /// it and not yet released: the changelog's "## Next" section.
    public static func bundled(includeNext: Bool = false) -> [ReleaseNote] {
        let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") ?? developmentFile.withLock { $0 }
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text, includeNext: includeNext)
    }

    /// The changelog for a run that has no bundle (SnapshotRunner), named through
    /// `DeepLinkRouter.installFixtures(changelog:)`. The app people install always has the
    /// bundled file and nothing in it sets this: it reads no environment variable.
    private static let developmentFile = OSAllocatedUnfairLock<URL?>(initialState: nil)
    public static func useDevelopmentFile(_ url: URL?) { developmentFile.withLock { $0 = url } }

    /// The notes for a channel: Releases as always; Beta and This Copy start with the "## Next" section of the
    /// changelog they follow (what is on development, what is in the clone), then the bundled releases.
    public static func channelNotes(channel: UpdateChannel, changelog: String?, includeNext: Bool) -> [ReleaseNote] {
        let released = bundled(includeNext: includeNext)
        guard channel != .releases, let changelog,
              let next = parse(changelog, includeNext: true).first(where: { $0.isUnreleased })
        else { return released }
        let title = channel == .beta ? "On Development — Not Yet Released" : "In Your Clone — Not Yet Released"
        return [next.renamed(title)] + released.filter { !$0.isUnreleased }
    }

    /// The newest release that has shipped: what the sidebar card announces.
    public static func newestReleased(in notes: [ReleaseNote]) -> ReleaseNote? {
        notes.filter { !$0.isUnreleased }
            .max { UpdateChecker.compare($0.version ?? "0", $1.version ?? "0") == .orderedAscending }
    }
}

extension WhatsNewItem {
    func renamed(releaseTitle: String) -> WhatsNewItem {
        WhatsNewItem(id: id, version: version, released: released, releaseTitle: releaseTitle, summary: summary, tagTitle: tagTitle,
                     body: body, scope: scope, symbol: symbol, image: image, topic: topic, isNotes: isNotes)
    }
}

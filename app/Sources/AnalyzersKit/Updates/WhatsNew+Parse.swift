import Foundation

/// Reading `CHANGELOG.md`: the one parser, for the app, `agent-runner` and `SnapshotRunner`.
///
/// A bullet may end with a tag that reads as nothing on GitHub:
/// `<!-- wn: open=recordings icon=film.stack title="Where Recordings Are Found" -->`.
/// A heading may be followed by `<!-- wn: released=2026-11-14 -->`. A tag that cannot be read leaves its
/// bullet untagged and the rest of the bullet still shows; `scripts/changelog-check.sh` is where a
/// malformed tag fails, before a release.
extension ReleaseNote {

    public static func parse(_ changelog: String, includeNext: Bool = false) -> [ReleaseNote] {
        changelog.components(separatedBy: "\n## ")
            .map { $0.hasPrefix("## ") ? String($0.dropFirst(3)) : $0 }
            .filter { $0.hasPrefix("v") || (includeNext && $0.hasPrefix("Next")) }
            .compactMap { section in
                let lines = section.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                guard let heading = lines.first else { return nil }
                return entry(heading: heading, lines: Array(lines.dropFirst()))
            }
    }

    private static func entry(heading: String, lines: [String]) -> ReleaseNote {
        let isNext = heading.hasPrefix("Next")
        let title = isNext ? unreleasedTitle : heading
        let version = isNext ? nil : heading.dropFirst().prefix { !$0.isWhitespace }.description

        // the release date is the file's own bookkeeping: a whole-line tag before any text of the entry. A tag on a
        // line of its own AFTER text belongs to the bullet above it (the tag may wrap onto its own line), so it stays
        // in the prose for the bullet to read; a second date line there is dropped.
        var released: Date?
        var prose: [String] = []
        var seenText = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let tag = WhatsNewTag.read(trimmed), trimmed.hasPrefix("<!--") {
                if !seenText { if let day = tag.released { released = day }; continue }
                if tag.released != nil, tag.open == nil, tag.icon == nil { continue }
            } else if !trimmed.isEmpty {
                seenText = true
            }
            prose.append(line)
        }

        var blocks = Self.blocks(from: prose)
        if isNext, case .paragraph(let first)? = blocks.first, first.hasPrefix("Notes for the release") {
            // the file's own note to whoever edits it is not release news
            blocks.removeFirst()
        }

        let releaseTitle = isNext ? unreleasedTitle : title.dropFirst((version?.count ?? 0) + 1)
            .drop { $0 == " " || $0 == "—" || $0 == "-" || $0 == ":" }.description
        var intro: [String] = [], closing: [String] = [], items: [WhatsNewItem] = []
        var topic: String?
        for block in blocks {
            switch block {
            case .paragraph(let text):
                if let heading = boldLine(text) { topic = heading }
                else if items.isEmpty { intro.append(text) }
                else { closing.append(text) }
            case .bullet(let text):
                items.append(item(text, position: items.count, version: version, released: released,
                                  releaseTitle: releaseTitle, topic: topic))
            }
        }
        if items.isEmpty, !(intro + closing).isEmpty {
            // a release written as prose alone has no bullets to be rows: it is one feature that says what the
            // release says, so it still shows (as an earlier change) instead of vanishing from the list
            let prose = (intro + closing).joined(separator: "\n\n")
            items = [WhatsNewItem(id: "\(version ?? "next")#0", version: version, released: released, releaseTitle: releaseTitle,
                                  summary: releaseTitle, tagTitle: nil, body: prose, scope: .untagged, symbol: nil, image: nil, topic: nil)]
            intro = []
            closing = []
        }
        return ReleaseNote(title: title, version: version, released: released, intro: intro, items: items, closing: closing)
    }

    /// "**Old Recordings**" on a line of its own: a topic heading inside a release.
    private static func boldLine(_ text: String) -> String? {
        guard text.hasPrefix("**"), text.hasSuffix("**"), text.count > 4 else { return nil }
        let inner = text.dropFirst(2).dropLast(2)
        return inner.contains("**") ? nil : String(inner)
    }

    private static func item(_ text: String, position: Int, version: String?, released: Date?,
                             releaseTitle: String, topic: String?) -> WhatsNewItem {
        var body = text
        var tag: WhatsNewTag?
        if let start = text.range(of: "<!--", options: .backwards), text.hasSuffix("-->"),
           let read = WhatsNewTag.read(String(text[start.lowerBound...])) {
            tag = read
            body = String(text[..<start.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        let scope: WhatsNewItem.Scope
        let symbol: String?
        switch (tag?.open, tag?.icon) {
        case let (open?, icon?) where open == "-": scope = .app; symbol = icon
        case let (open?, icon?): scope = .screen(open); symbol = icon
        default: scope = .untagged; symbol = nil
        }
        let summary = (scope == .untagged ? nil : tag?.title) ?? firstSentence(of: body)
        return WhatsNewItem(id: "\(version ?? "next")#\(position)", version: version, released: released,
                            releaseTitle: releaseTitle, summary: summary, tagTitle: tag?.title, body: body, scope: scope, symbol: symbol,
                            image: tag?.image, topic: topic)
    }

    /// The bullet's first sentence as plain words: Markdown marks and the final full stop removed.
    static func firstSentence(of body: String) -> String {
        let plain = body.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        let end = plain.range(of: ". ")?.lowerBound ?? plain.endIndex
        var sentence = String(plain[..<end])
        if sentence.hasSuffix(".") { sentence.removeLast() }
        // a row is one line of a list: a sentence that runs on (the changelog before it was written for readers)
        // stops at a word and says so; the whole bullet is one level down
        if sentence.count > maxSummary {
            let cut = sentence.prefix(maxSummary)
            let words = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
            sentence = words.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:—-")) + "…"
        }
        return sentence
    }

    /// The longest a feature's one line is before it is cut at a word.
    static let maxSummary = 110

    /// A piece of an entry as it should READ: the file is hard-wrapped at 78 columns for editing, but on
    /// screen a paragraph is one flowing paragraph and a list item is one item.
    enum Block {
        case paragraph(String)
        case bullet(String)
    }

    /// Blank lines separate paragraphs; "- " starts a list item; any other line continues whatever came before it.
    static func blocks(from lines: [String]) -> [Block] {
        var result: [Block] = []
        var current: (isBullet: Bool, text: String)?

        func flush() {
            guard let open = current, !open.text.isEmpty else { current = nil; return }
            result.append(open.isBullet ? .bullet(open.text) : .paragraph(open.text))
            current = nil
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flush()
                current = (true, String(trimmed.dropFirst(2)))
            } else if let open = current {
                current = (open.isBullet, open.text + " " + trimmed)
            } else {
                current = (false, trimmed)
            }
        }
        flush()
        return result
    }
}

/// What a `<!-- wn: … -->` comment says. Comments with another prefix are not read.
struct WhatsNewTag {
    var open: String?
    var icon: String?
    var title: String?
    var image: String?
    var released: Date?

    /// The tag in `comment` (the whole `<!-- … -->`), or nil when it is not one of ours.
    static func read(_ comment: String) -> WhatsNewTag? {
        guard comment.hasPrefix("<!--"), comment.hasSuffix("-->") else { return nil }
        let inner = comment.dropFirst(4).dropLast(3).trimmingCharacters(in: .whitespaces)
        guard inner.hasPrefix("wn:") else { return nil }
        var tag = WhatsNewTag()
        for (key, value) in pairs(String(inner.dropFirst(3))) where !value.isEmpty {
            switch key {
            case "open": tag.open = value
            case "icon": tag.icon = value
            case "title": tag.title = value
            case "image": tag.image = value
            case "released": tag.released = day(value)
            default: break
            }
        }
        return tag
    }

    /// `key=value` and `key="a value with spaces"`, in order.
    private static func pairs(_ text: String) -> [(String, String)] {
        var result: [(String, String)] = []
        var rest = Substring(text)
        while let equals = rest.firstIndex(of: "=") {
            let key = rest[..<equals].trimmingCharacters(in: .whitespaces)
            rest = rest[rest.index(after: equals)...]
            var value: String
            if rest.first == "\"" {
                rest = rest.dropFirst()
                let close = rest.firstIndex(of: "\"") ?? rest.endIndex
                value = String(rest[..<close])
                rest = close == rest.endIndex ? "" : rest[rest.index(after: close)...]
            } else {
                let end = rest.firstIndex(where: \.isWhitespace) ?? rest.endIndex
                value = String(rest[..<end])
                rest = rest[end...]
            }
            result.append((key, value))
        }
        return result
    }

    /// "2026-11-14" as that day at noon in the reader's calendar, so it never shifts a day on screen.
    private static func day(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

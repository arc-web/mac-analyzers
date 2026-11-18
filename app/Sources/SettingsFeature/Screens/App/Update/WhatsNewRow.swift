import SwiftUI
import AnalyzersKit
import UIComponents

/// One feature as a row: its icon, its title and a one-line description. The release and date are on the screen
/// that lists it, not repeated on every row. A click pushes the feature's own screen.
struct WhatsNewRow: View {
    let item: WhatsNewItem
    /// Shows the "New" mark: the feature came with a release newer than the one the person last saw.
    let isNew: Bool
    let onOpen: () -> Void

    private static let iconWidth: CGFloat = 24

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Tokens.Space.xl) {
                // a Label centres its icon on both lines of the row, the system's own way
                Label {
                    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                        Text(item.summary)
                        if let line = WhatsNewText.description(item) {
                            Text(WhatsNewText.styled(line))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } icon: {
                    // an icon column is the actual job of this width: symbols differ in width, and without one the
                    // titles of the rows would start at different places
                    Image(systemName: item.symbol ?? "sparkles")
                        .frame(width: Self.iconWidth)
                }
                Spacer(minLength: Tokens.Space.xl)
                if isNew {
                    Text(Names.WhatsNew.new)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Names.WhatsNew.opensThisFeature)
    }
}

/// How a feature's release and date read, and how the changelog's Markdown is set as text.
enum WhatsNewText {
    /// "v2.71.0 · 14 Nov"; "Not yet released" for the unreleased section.
    static func arrived(_ item: WhatsNewItem) -> String {
        arrived(version: item.version, released: item.released)
    }

    static func arrived(version: String?, released: Date?) -> String {
        guard let version else { return Names.WhatsNew.notYetReleased }
        let day = released.map { $0.formatted(.dateTime.day().month(.abbreviated)) }
        return ["v\(version)", day].compactMap { $0 }.joined(separator: " · ")
    }

    /// The row's second line: the first sentence of the bullet that is not already the title (the tag's title is a name, so
    /// the sentence is the description; an untagged bullet's first sentence is its title, so the next one is). Nil when
    /// there is nothing more to say.
    static func description(_ item: WhatsNewItem) -> String? {
        let sentences = sentences(of: item.body)
        let candidate = sentences.first { $0 != item.summary }
        return candidate.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The sentences of a paragraph, each ending at ". ", "! " or "? " (a full stop inside `code` or a number is not one).
    static func sentences(of text: String) -> [String] {
        var result: [String] = [], current = "", inCode = false
        let chars = Array(text.replacingOccurrences(of: "\n", with: " "))
        for (index, char) in chars.enumerated() {
            current.append(char)
            if char == "`" { inCode.toggle() }
            let next = index + 1 < chars.count ? chars[index + 1] : " "
            if !inCode, ".!?".contains(char), next == " " {
                result.append(current.trimmingCharacters(in: .whitespaces)); current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { result.append(rest) }
        return result
    }

    /// `code` spans and **emphasis** in the changelog render as such; text that isn't valid Markdown is shown as written.
    static func styled(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

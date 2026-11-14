import SwiftUI
import AnalyzersKit
import UIComponents

/// One feature as a row: its icon, its one line, and where and when it arrived. A click pushes the
/// feature's own screen.
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
                        Text(WhatsNewText.arrived(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        .accessibilityHint("Opens this feature")
    }
}

/// How a feature's release and date read, and how the changelog's Markdown is set as text.
enum WhatsNewText {
    /// "v2.71.0 · 14 Nov"; "Not yet released" for the unreleased section.
    static func arrived(_ item: WhatsNewItem) -> String {
        arrived(version: item.version, released: item.released)
    }

    static func arrived(version: String?, released: Date?) -> String {
        guard let version else { return "Not yet released" }
        let day = released.map { $0.formatted(.dateTime.day().month(.abbreviated)) }
        return ["v\(version)", day].compactMap { $0 }.joined(separator: " · ")
    }

    /// `code` spans and **emphasis** in the changelog render as such; text that isn't valid Markdown is shown as written.
    static func styled(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

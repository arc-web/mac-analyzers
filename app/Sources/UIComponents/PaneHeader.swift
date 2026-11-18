import SwiftUI

/// General-pane-style header: large tile, title, one-line description —
/// opens every settings pane so they all share the same anatomy.
public struct PaneHeader: View {
    let symbol: String
    let color: Color
    let title: String
    let caption: String
    /// A picture in place of the tile (the app's own icon), drawn at the tile's size class times 1.5.
    let logo: Image?
    /// A small line under the title, such as a version.
    let detail: String?

    public init(symbol: String, color: Color, title: String, caption: String) {
        self.symbol = symbol
        self.color = color
        self.title = title
        self.caption = caption
        self.logo = nil
        self.detail = nil
    }

    /// The header of a screen about the app itself: its logo instead of a symbol tile.
    public init(logo: Image, title: String, detail: String? = nil, caption: String) {
        self.symbol = ""
        self.color = .clear
        self.title = title
        self.caption = caption
        self.logo = logo
        self.detail = detail
    }

    public var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Group {
                if let logo {
                    logo.resizable().interpolation(.high).frame(width: Tokens.Icon.hero * 1.5, height: Tokens.Icon.hero * 1.5)
                } else {
                    IconTile(symbol: symbol, color: color, side: 44)
                }
            }
            .accessibilityHidden(true)  // decorative — title below already names the pane
            Text(title).font(.title2.weight(.bold))
            if let detail { Text(detail).font(.callout).monospacedDigit().foregroundStyle(.secondary) }
            Text(caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.l)
        .padding(.horizontal, Tokens.Space.pane)
    }
}

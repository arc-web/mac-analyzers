import SwiftUI
import UIComponents

/// One nested area of a hub: a screen the hub leads to, named as the sidebar names it.
struct HubArea: Identifiable {
    let title: String
    let caption: String
    let symbol: String
    let color: Color
    /// A deep-link target (`DeepLinkRouter`), opened through the `Navigator`.
    let target: String
    var id: String { target }
}

/// "This is where you are": the settings panes' header (`PaneHeader`: tile, title, one line) followed by the hub's
/// nested areas as rows that open them, as System Settings' General does. For a hub — a screen whose job is to lead
/// to others (Overview, Disk) — never for a screen that is a table or a list (Monitor, Activity, a review): those
/// are `DataScreen`s and start with their data. It goes INSIDE the screen's scroll content as its first item, like
/// `PaneScaffold`'s header, never above it in the toolbar's backdrop.
struct HubHeader: View {
    @Environment(Navigator.self) private var navigator
    let symbol: String
    let color: Color
    let title: String
    let caption: String
    var areas: [HubArea] = []

    var body: some View {
        VStack(spacing: Tokens.Space.xxl) {
            PaneHeader(symbol: symbol, color: color, title: title, caption: caption)
            if !areas.isEmpty {
                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(areas) { area in
                            if area.id != areas.first?.id { Divider() }
                            row(area)
                        }
                    }
                }
            }
        }
    }

    private func row(_ area: HubArea) -> some View {
        Button { navigator.open(target: area.target) } label: {
            HStack(spacing: Tokens.Space.xl) {
                IconTile(symbol: area.symbol, color: area.color, side: 28)
                    .accessibilityHidden(true)  // decorative — the title beside it names the area
                VStack(alignment: .leading, spacing: Tokens.Space.hair) {
                    Text(area.title)
                    Text(area.caption).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: Tokens.Space.m)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)  // decorative — the row opens the area
            }
            .padding(.vertical, Tokens.Space.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

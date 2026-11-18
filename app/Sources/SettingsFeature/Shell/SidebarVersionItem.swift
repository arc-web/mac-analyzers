import AppKit
import SwiftUI
import AnalyzersKit
import UIComponents

/// The pinned item at the foot of the sidebar: one row with the app's icon, its name and, under it, where it stands
/// (Up to Date, Update Available, or the version while no check has answered). A click opens the Mac Analyzers
/// screen, which leads to Updates, What's New, How It Works and Support; the row shows as selected on any of them.
/// It is part of the sidebar, so it goes when the sidebar is collapsed.
struct SidebarVersionItem: View {
    let navigator: Navigator
    /// In the hover overlay the footer sits on the panel's glass with the same material, not the sidebar's opaque bar.
    var floating = false
    @Environment(UpdateState.self) private var updates

    private var selected: Bool { AppGroup.sections.contains(navigator.section) }

    var body: some View {
        Button {
            navigator.open(Location(AppGroup.app))
        } label: {
            HStack(spacing: Tokens.Space.xl) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high)
                    .frame(width: Tokens.Icon.card + 6, height: Tokens.Icon.card + 6)
                    .accessibilityHidden(true)  // decorative — the name beside it says what it is
                VStack(alignment: .leading, spacing: Tokens.Space.hair) {
                    Text(Names.app).font(.subheadline.weight(.semibold))
                    stateLabel
                }
                Spacer(minLength: 0)
            }
            .padding(Tokens.Space.m)
            .background(selected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(Tokens.Space.m)
        .background(floating ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.bar))
        .help("Open \(Names.app) · \(updates.build.versionText)")
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(Names.app)")
    }

    @ViewBuilder private var stateLabel: some View {
        if let state {
            Label(state.text, systemImage: state.symbol)
                .font(.caption)
                .foregroundStyle(state.tint)
        } else {
            Text(updates.build.sidebarText).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Nothing until a check has answered: an app that cannot reach the
    /// network says only its version rather than claiming to be current.
    private var state: (text: String, symbol: String, tint: Color)? {
        switch updates.summary {
        case .updateAvailable?: return (Names.State.updateAvailable, "arrow.down.circle.fill", .orange)
        case .developmentBuild?: return (Names.State.developmentBuild, "hammer.fill", .blue)
        case .upToDate?: return (Names.State.upToDate, "checkmark.circle.fill", .secondary)
        case nil: return nil
        }
    }
}

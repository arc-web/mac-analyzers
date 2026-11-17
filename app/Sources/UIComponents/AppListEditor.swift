import AppKit
import AnalyzersKit
import SwiftUI

/// List editor backed by REALITY: rows show the app's actual icon, and the
/// Add sheet is a searchable picker over installed apps (or, for process-name
/// fragments, over what's running right now) — no more guessing names into a
/// blind text field. A custom-entry field stays for the edge cases.
public struct AppListEditor: View {

    public enum Mode {
        case installedApps      // reclaim list, stale apps
        case processFragments   // protected processes (ps-args fragments)
    }

    let title: String
    let mode: Mode
    let height: CGFloat
    @Binding var items: [String]
    @State private var selection: String?
    @State private var showPicker = false

    public init(title: String, mode: Mode, items: Binding<[String]>,
                height: CGFloat = 120) {
        self.title = title
        self.mode = mode
        self.height = height
        self._items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(title).font(.subheadline.weight(.medium))
            List(selection: $selection) {
                ForEach(items, id: \.self) { item in
                    AppNameLabel(name: item, mode: mode)
                        .tag(item)
                }
            }
            // FIXED height: the list scrolls WITHIN itself instead of
            // growing (predictable card size; wheel targets the inner list)
            .frame(height: height)
            .border(.separator)
            HStack {
                Button {
                    showPicker = true
                } label: {
                    Label("Add…", systemImage: "plus")
                }
                Button("Remove") {
                    if let selection { items.removeAll { $0 == selection } }
                    selection = nil
                }
                .disabled(selection == nil)
                Spacer()
            }
        }
        .appPicker(isPresented: $showPicker, mode: mode, existing: items) { picked in
            if !items.contains(picked) { items.append(picked) }
        }
    }
}

/// A name in an app list with the app's own icon when an installed app has that name, otherwise a symbol for an app or a
/// program: what every list of apps and program names shows on its rows.
public struct AppNameLabel: View {
    let name: String
    let mode: AppListEditor.Mode

    public init(name: String, mode: AppListEditor.Mode) {
        self.name = name
        self.mode = mode
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s) {
            icon
                .accessibilityHidden(true)  // decorative — the name text is the identity
            Text(name)
        }
    }

    @ViewBuilder private var icon: some View {
        if let app = Self.installedByName[name.lowercased()] {
            Image(nsImage: Self.icon(path: app.path))
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            IconTile(symbol: mode == .installedApps ? "app.dashed" : "terminal.fill", color: .gray)
        }
    }

    private static let installedByName: [String: InstalledApp] =
        Dictionary(AppCatalog.installedApps().map { ($0.name.lowercased(), $0) },
                   uniquingKeysWith: { first, _ in first })

    private static func icon(path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }
}

public extension View {
    /// The searchable Add sheet of `AppListEditor`, for a list kept somewhere else: installed apps (or, for program names,
    /// what is running now) with their icons, a search field, and a field for a name that is not listed.
    func appPicker(isPresented: Binding<Bool>, mode: AppListEditor.Mode, existing: [String],
                   onPick: @escaping (String) -> Void) -> some View {
        sheet(isPresented: isPresented) {
            AppPickerSheet(mode: mode, existing: existing, onPick: onPick)
        }
    }
}

/// The searchable Add sheet.
private struct AppPickerSheet: View {
    let mode: AppListEditor.Mode
    let existing: [String]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var custom = ""
    @State private var apps: [InstalledApp] = []
    @State private var running: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text(mode == .installedApps ? "Pick an installed app" : "Pick a running process")
                .font(.headline)
            TextField("Search…", text: $search)
                .textFieldStyle(.roundedBorder)

            List {
                if mode == .installedApps {
                    ForEach(filteredApps) { app in
                        Button {
                            onPick(app.name)
                            dismiss()
                        } label: {
                            HStack(spacing: Tokens.Space.m) {
                                Image(nsImage: icon(app.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .accessibilityHidden(true)  // decorative — the name text is the identity
                                Text(app.name)
                                Spacer()
                                if existing.contains(app.name) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(filteredRunning, id: \.self) { name in
                        Button {
                            onPick(name)
                            dismiss()
                        } label: {
                            HStack(spacing: Tokens.Space.m) {
                                IconTile(symbol: "terminal.fill", color: .blue)
                                    .accessibilityHidden(true)  // decorative — the name text is the identity
                                Text(name)
                                Spacer()
                                if existing.contains(name) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 260)

            HStack {
                TextField(mode == .installedApps ? "Or type a name…" : "Or type a fragment…",
                          text: $custom)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCustom)
                Button("Add", action: addCustom)
                    .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .scenePadding()
        .frame(minWidth: 420, minHeight: 430)
        .onAppear {
            if mode == .installedApps {
                apps = AppCatalog.installedApps()
            } else {
                running = AppCatalog.runningNameSuggestions()
            }
        }
    }

    private var filteredApps: [InstalledApp] {
        search.isEmpty ? apps
            : apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var filteredRunning: [String] {
        search.isEmpty ? running
            : running.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private func addCustom() {
        let trimmed = custom.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onPick(trimmed)
        dismiss()
    }

    private func icon(_ path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 20, height: 20)
        return icon
    }
}

import AnalyzersKit
import SwiftUI
import UIComponents

/// Monitor's real table on rows from the real process table, driven the way a person and the clock drive
/// it, for `snapshot-runner --outline-probe monitor:<case>` (which counts what AppKit logs while it runs). It is
/// the table of `MonitorView` and nothing else: the same `MonitorOutline`, the same model, the same filter and the same sort
/// rule. It is public only so SnapshotRunner can host it; the app people install never creates one.
@MainActor @Observable
public final class MonitorProbe {
    let model = MonitorModel()
    var selection: MonitorRow.ID?
    var sortOrder: [KeyPathComparator<MonitorRow>] = [KeyPathComparator(\MonitorRow.memoryBytes, order: .reverse)]
    var scope: MonitorView.Scope = .everything
    var search = ""
    private var spawned = 0

    public init() {
        // what an earlier probe process left open is not this one's start
        model.expansion.ids = []
    }

    public var view: some View { MonitorProbeView(probe: self) }

    // MARK: - what the clock and the person do

    /// The first reading, and later readings: values and membership change, order does not.
    public func load() async { await model.refresh(force: true) }
    public func tick() async { await model.refresh() }
    public func refreshNow() async { await model.refreshNow() }

    public func sort(by name: String) {
        switch name {
        case "cpu": sortOrder = [KeyPathComparator(\MonitorRow.cpuSort, order: .reverse)]; model.setSort(.init(.cpu, ascending: false))
        case "name": sortOrder = [KeyPathComparator(\MonitorRow.name)]; model.setSort(.init(.name, ascending: true))
        default: sortOrder = [KeyPathComparator(\MonitorRow.memoryBytes, order: .reverse)]; model.setSort(.init(.memory, ascending: false))
        }
    }

    public func filter(_ text: String) { search = text }

    public func showScope(_ name: String) { scope = MonitorView.Scope(rawValue: name) ?? .everything }

    public func openFirstGroup() {
        if let first = model.rows.first(where: \.hasChildren) { model.open([first.id]) }
    }

    public func openAll() { model.expandEverything() }
    public func closeAll() { model.expansion.ids = [] }

    /// A process starts and another ends inside the first open group that has two or more: the rows change
    /// in an open group, which is what used to be held back.
    public func churn() {
        spawned += 1
        var rows = model.rows
        guard let index = rows.firstIndex(where: { model.expansion.ids.contains($0.id) && $0.children.count >= 2 }) else { return }
        var group = rows[index]
        var fresh = group.children
        fresh.removeLast()
        if let template = fresh.first {
            fresh.append(template.copy(id: "probe-new-\(spawned)", name: "New \(spawned)", pid: 900_000 + spawned))
        }
        group.children = MonitorTree.merge(group.children, with: fresh)
        rows[index] = group
        model.setRows(rows)
    }

    public var rowCount: Int { MonitorTree.order(of: model.rows).count }
    public var groupCount: Int { model.rows.count }
    public var openCount: Int { model.expansion.ids.count }
    public var isLoaded: Bool { model.isLoaded(.memory) }
}

private struct MonitorProbeView: View {
    @Bindable var probe: MonitorProbe

    var body: some View {
        MonitorOutline(rows: MonitorTree.filtered(probe.model.rows, category: probe.scope.category, search: probe.search),
                       sortOrder: $probe.sortOrder, selection: $probe.selection,
                       expanded: probe.model.expansion.binding, icons: probe.model.icons,
                       isLoading: !probe.model.isLoaded(.memory),
                       empty: AnyView(Text("Nothing here")),
                       rowFor: { probe.model.row($0) }, begin: { _ in }, open: { _ in }) { _ in EmptyView() }
    }
}

/// Monitor's stop sheet on programs given to it, for `snapshot-runner --stop-sheet`: the same `MonitorStopSheet` the screen
/// opens, so a render shows what a person is asked. Public only so SnapshotRunner can host it; the app people install never creates one.
public struct MonitorStopSheetPreview: View {
    let group: String
    let programs: [StopTarget]
    /// Every program a person may stop is ticked, as after Select All.
    let ticked: Bool

    public init(group: String, programs: [StopTarget], ticked: Bool = false) {
        self.group = group
        self.programs = programs
        self.ticked = ticked
    }

    public var body: some View {
        MonitorStopSheet(group: group, programs: programs,
                         preticked: ticked ? Set(programs.filter(\.isStoppableByPerson).map(\.id)) : [],
                         onCancel: {}, onStop: { _ in })
    }
}

/// The lock cell at rest and with the pointer on it, side by side, for `snapshot-runner --lock-cell` (a render has no pointer).
public struct MonitorLockCellPreview: View {
    let row: MonitorRow

    public init(row: MonitorRow) { self.row = row }

    public var body: some View {
        Form {
            LabeledContent("At rest") { MonitorStopCell(row: row, verb: "Stop", help: "", action: {}) }
            LabeledContent("Pointer on it") { MonitorStopCell(row: row, verb: "Stop", help: "", action: {}, showsButton: true) }
            Text(row.lockTip ?? "").foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

/// Monitor's details panel on a row given to it, for `snapshot-runner --lock-cell` (the panel of a row in a headless window is not drawn).
public struct MonitorInspectorPreview: View {
    let row: MonitorRow
    @State private var model = MonitorModel()
    @State private var navigator = Navigator(initial: SectionRegistry.home)

    public init(row: MonitorRow) { self.row = row }

    public var body: some View {
        MonitorInspector(model: model, row: row, begin: { _ in }, showDetails: { _ in })
            .environment(navigator)
    }
}

import Foundation
@_spi(TestSupport) import AnalyzersKit

// `agent-runner --probe-whats-new [--changelog <file>]` prints every release of a changelog the way What's New reads it
// (default: this checkout's CHANGELOG.md): each release, its date, its features with their screen and icon, and the
// fallback group an untagged bullet lands in; it fails when a release yields no features or a feature has no summary.
// `--probe-whats-new-fixture` judges the parser on `app/Fixtures/whats-new.md` (a tagged release, an untagged one with
// topic lines, an untagged one with none) and exits non-zero when a rule breaks. Reads files, writes nothing.

private func checkoutRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() }      // WhatsNewProbe.swift → AgentRunner → Sources → app → checkout
    return url
}

func probeWhatsNew(_ args: [String]) -> Never {
    let file = args.firstIndex(of: "--changelog").flatMap { args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil }
        ?? checkoutRoot().appending(path: "CHANGELOG.md")
    guard let text = try? String(contentsOf: file, encoding: .utf8) else {
        print("FAIL  cannot read \(file.path)")
        exit(1)
    }
    let notes = ReleaseNote.parse(text, includeNext: true)
    var failed = false
    for note in notes {
        let tagged = note.items.filter { $0.scope != .untagged }.count
        let date = note.released.map { $0.formatted(.iso8601.year().month().day()) } ?? "no date"
        print("\(note.title.prefix(70))  [\(date)]  \(note.items.count) features, \(tagged) tagged")
        if note.items.isEmpty { print("  FAIL  no features"); failed = true }
        for item in note.items {
            let place: String
            switch item.scope {
            case .screen(let target): place = "screen \(target)"
            case .app: place = "throughout the app"
            case .untagged: place = item.topic.map { "topic \($0)" } ?? "earlier changes"
            }
            if item.summary.isEmpty { print("  FAIL  empty summary in \(item.id)"); failed = true }
            print("  \(item.symbol ?? "·")  \(item.summary.prefix(60))  → \(place)")
        }
    }
    print(failed ? "\nFAILED" : "\n\(notes.count) release(s) read")
    exit(failed ? 1 : 0)
}

func probeWhatsNewFixture() -> Never {
    let file = checkoutRoot().appending(path: "app/Fixtures/whats-new.md")
    var failed = false
    func check(_ name: String, _ ok: Bool, _ detail: String) {
        print("  \(ok ? "ok  " : "FAIL") \(name): \(detail)")
        if !ok { failed = true }
    }
    guard let text = try? String(contentsOf: file, encoding: .utf8) else {
        print("FAIL  cannot read \(file.path)")
        exit(1)
    }
    let released = ReleaseNote.parse(text)
    let all = ReleaseNote.parse(text, includeNext: true)
    check("three releases, and the unreleased one only when asked", released.count == 4 && all.count == 5 && all.first?.isUnreleased == true,
          "\(released.count) released, \(all.count) with the unreleased section")
    guard let tagged = released.first(where: { $0.version == "9.3.0" }),
          let topics = released.first(where: { $0.version == "9.2.0" }),
          let bare = released.first(where: { $0.version == "9.1.0" }) else { print("FAIL  fixture releases missing"); exit(1) }

    check("the tagged release reads every bullet as a tagged feature", tagged.items.count == 8 && tagged.items.allSatisfy { $0.scope != .untagged && $0.symbol != nil },
          "\(tagged.items.count) features")
    check("a tag's screen, icon and title are read", tagged.items.first.map { $0.target == "guard" && $0.symbol == "shield.lefthalf.filled" && $0.summary == "Guard Events as Rows" } == true,
          tagged.items.first.map { "\($0.target ?? "-") \($0.symbol ?? "-") \($0.summary)" } ?? "none")
    check("open=- is a change across the app, not a screen", tagged.items.last?.scope == .app, "\(String(describing: tagged.items.last?.scope))")
    check("a bullet with no title takes its first sentence", tagged.items.first(where: { $0.target == "recordings" })?.summary
          == "Old Recordings finds where Zoom and screen recordings are saved and shows each place as its own tab",
          tagged.items.first(where: { $0.target == "recordings" })?.summary ?? "none")
    check("no tag is left in what a person reads", !tagged.items.contains { $0.body.contains("wn:") || $0.summary.contains("<!--") }, "bodies and summaries are prose")
    let day = tagged.released.map { Calendar.current.dateComponents([.year, .month, .day], from: $0) }
    check("the date under the heading is read and is not shown as text", day?.year == 2026 && day?.month == 11 && day?.day == 14
          && !tagged.intro.contains { $0.contains("wn:") }, "\(day?.year ?? 0)-\(day?.month ?? 0)-\(day?.day ?? 0)")
    check("the intro and the closing line are kept apart from the features", tagged.intro.count == 1 && tagged.closing == ["Minor fixes and improvements throughout."],
          "intro \(tagged.intro.count), closing \(tagged.closing)")

    check("an untagged release keeps its bold topic on each bullet", topics.items.map(\.topic) == ["Memory", "Memory", "The window", "The window"]
          && topics.items.allSatisfy { $0.scope == .untagged && $0.symbol == nil }, "\(topics.items.map { $0.topic ?? "-" })")
    check("an untagged release with no topics has none", bare.items.count == 3 && bare.items.allSatisfy { $0.topic == nil && $0.scope == .untagged }, "\(bare.items.count) features")
    check("a bold topic line is not a feature or an intro", !topics.items.contains { $0.body.hasPrefix("**") } && topics.intro.count == 1, "intro \(topics.intro.count)")
    check("no feature has an empty summary", all.flatMap(\.items).allSatisfy { !$0.summary.isEmpty }, "\(all.flatMap(\.items).count) features")
    check("feature ids are unique", Set(all.flatMap(\.items).map(\.id)).count == all.flatMap(\.items).count, "\(all.flatMap(\.items).count) ids")
    check("the newest shipped release is the one a card announces", ReleaseNote.newestReleased(in: all)?.version == "9.3.0", ReleaseNote.newestReleased(in: all)?.version ?? "none")
    check("the unreleased section is read as tagged features and the editor's note is dropped", all.first?.items.count == 1 && all.first?.intro == ["What is being built now, ahead of the next release."],
          "\(all.first?.items.count ?? -1) feature(s), intro \(all.first?.intro ?? [])")

    // a release written as prose alone has no bullets: it is one feature, so it still shows
    let prose = released.first { $0.version == "9.0.0" }
    check("a release with no bullets is one feature that says what the release says", prose?.items.count == 1 && prose?.items.first?.summary == "A release written as prose alone"
          && prose?.items.first?.scope == .untagged && prose?.items.first?.body.contains("The second paragraph") == true && prose?.intro.isEmpty == true,
          "\(prose?.items.count ?? -1) feature(s)")

    // a tag that cannot be read leaves the bullet untagged and the rest of it still shows
    let broken = ReleaseNote.parse("""
        ## v1.0.0 — A release with a broken tag

        - This bullet has a tag with nothing usable in it, and its words still show. <!-- wn: open= icon= -->
        - This one has a tag from some other tool and keeps it out of the way. <!-- wn: open=guard -->
        """)
    check("a malformed tag leaves the bullet untagged and its words in place", broken.first?.items.count == 2 && broken.first?.items.allSatisfy { $0.scope == .untagged && !$0.body.contains("wn:") } == true,
          "\(broken.first?.items.map { String(describing: $0.scope) } ?? [])")
    exit(failed ? 1 : 0)
}

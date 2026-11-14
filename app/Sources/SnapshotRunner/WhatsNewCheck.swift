import AppKit
import AnalyzersKit
import SettingsFeature

/// `snapshot-runner --check-whats-new <changelog> <version|next>`: whether every screen and icon the What's New tags of
/// one entry name really exist in THIS app. Only the app's code knows them (the deep-link table, the system's symbols,
/// the title style), so `scripts/changelog-check.sh --on-mac` asks this tool, from the checks, `cut-release.sh` and
/// `release.sh`. Reads the file it is given and nothing else; prints each failure with the bullet; exits 1 on any.
@MainActor
enum WhatsNewCheck {
    static func run(_ arguments: [String]) -> Never {
        guard arguments.count >= 3, let text = try? String(contentsOfFile: arguments[1], encoding: .utf8) else {
            FileHandle.standardError.write(Data("usage: snapshot-runner --check-whats-new <changelog> <version|next>\n".utf8))
            exit(2)
        }
        let wanted = arguments[2].lowercased() == "next" ? nil : arguments[2].trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let notes = ReleaseNote.parse(text, includeNext: true)
        guard let note = notes.first(where: { wanted == nil ? $0.isUnreleased : $0.version == wanted }) else {
            FileHandle.standardError.write(Data("changelog: no entry for \(arguments[2]) to check.\n".utf8))
            exit(1)
        }
        var failures: [String] = []
        var tagged = 0
        for (position, item) in note.items.enumerated() {
            let name = "bullet \(position + 1) (\"\(item.summary)\")"
            if case .screen(let target) = item.scope {
                let landed = DeepLinkRouter.probeRouting(of: target)
                if landed.contains("unknown") { failures.append("\(name): open=\(target) is not a screen the app opens") }
            }
            if let symbol = item.symbol {
                if NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil {
                    failures.append("\(name): icon=\(symbol) is not a symbol this system has")
                }
            }
            if let title = item.tagTitle {
                for violation in TitleStyle.violations(in: title) { failures.append("\(name): title \"\(title)\" — \(violation)") }
            }
            if item.scope != .untagged { tagged += 1 }
        }
        for failure in failures { FileHandle.standardError.write(Data("  • \(failure)\n".utf8)) }
        if failures.isEmpty {
            print("changelog: \(note.items.count) bullet(s) of \(note.title.prefix(40)), \(tagged) tagged — every screen, icon and title checks out in this app")
        } else {
            FileHandle.standardError.write(Data("changelog: \(failures.count) tag problem(s) in \(note.title)\n".utf8))
        }
        exit(failures.isEmpty ? 0 : 1)
    }
}

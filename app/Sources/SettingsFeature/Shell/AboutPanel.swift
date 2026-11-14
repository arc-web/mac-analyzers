import AppKit
import AnalyzersKit

/// The standard "About Mac Analyzers" window: the system's panel shows the name, icon and version on its own; the credits
/// line carries the link to the README that used to sit at the foot of How It Works.
@MainActor
enum AboutPanel {
    static let readme = URL(string: "https://github.com/hrconsultnj/mac-analyzers")!

    static func show() {
        let credits = NSMutableAttributedString(
            string: "README on GitHub",
            attributes: [.link: readme, .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)])
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centred, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate()
    }
}

import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case appearance, lighting, keyboard, sound, dock, permissions
    var id: Self { self }

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .lighting: "Lighting"
        case .keyboard: "Keyboard"
        case .sound: "Sound"
        case .dock: "Dock"
        case .permissions: "Permissions"
        }
    }

    var icon: SolarIcon {
        switch self {
        case .appearance: .palette
        case .lighting: .sun
        case .keyboard: .keyboard
        case .sound: .volume
        case .dock: .monitor
        case .permissions: .shield
        }
    }

    /// Pages that change the board's look show a live preview.
    var showsPreview: Bool { [.appearance, .lighting, .keyboard].contains(self) }
}

/// Which settings page is showing; shared so the menu bar can open a specific page.
@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage
    init(_ page: SettingsPage = .appearance) { self.page = page }
}

struct SettingsWindow: View {

    @ObservedObject var prefs: Preferences
    @ObservedObject var store: DockStore
    let sound: SoundEngine
    @ObservedObject var permissions: Permissions
    @ObservedObject var navigation: SettingsNavigation
    private var page: SettingsPage { navigation.page }
    @Environment(\.snapshotLayout) private var snapshotLayout

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            // The only divider: a muted 2 pt line. Sidebar and page share one background.
            Rectangle().fill(Radix.slate3).frame(width: 2)
            if snapshotLayout {
                // An overlay doesn't size its parent, so a tall page pins to the top and clips.
                Color.clear
                    .overlay(alignment: .top) { detail.fixedSize(horizontal: false, vertical: true) }
                    .clipped()
            } else {
                ScrollView { detail }.scrollContentBackground(.hidden)
            }
        }
        // Fill the whole window, title bar included, so the traffic lights sit inside
        // the sidebar. A fixed height here would leave a gap at the bottom.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Radix.slate1)
        .preferredColorScheme(prefs.appearance.scheme)
        .onAppear { permissions.refresh() }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var detail: some View {
        VStack(alignment: .leading, spacing: 40) {
            PageHeader(title: page.title, subtitle: subtitle)
            if page.showsPreview {
                BoardPreview(store: store, prefs: prefs, sound: sound)
            }
            content
        }
        .padding(.horizontal, 48)
        .padding(.top, 56)
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Pages cross-fade with a slight blur: in after a short beat, out quicker.
        .id(page)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .modifier(active: BlurFade(amount: 1), identity: BlurFade(amount: 0))
                .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24).delay(0.06)),
            removal: .modifier(active: BlurFade(amount: 1), identity: BlurFade(amount: 0))
                .animation(.easeIn(duration: 0.15))
        ))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Muted logo above the title, lined up with the option icons below.
            Image(nsImage: StatusItemController.placeholderLogo)
                .renderingMode(.template)
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundStyle(Radix.slate10)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .accessibilityHidden(true)
            Text("Marbly")
                .typeStyle(.heading)
                .foregroundStyle(Radix.slate12)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            ForEach(SettingsPage.allCases) { item in
                Button { withAnimation { navigation.page = item } } label: {
                    // Fixed icon column so labels line up whatever each symbol's width.
                    HStack(spacing: 12) {
                        Solar(item.icon, size: 20)
                        Text(item.title)
                    }
                    .typeStyle(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SidebarItemStyle(selected: page == item))
                .accessibilityAddTraits(page == item ? .isSelected : [])
            }
            Spacer()
            SidebarFooter()
        }
        // Options run nearly edge to edge.
        .padding(.horizontal, 8)
        // Clear the window's traffic lights.
        .padding(.top, 52)
        .frame(width: 248)
    }

    private var subtitle: String {
        switch page {
        case .appearance: "Themes, case colour and how this window looks."
        case .lighting: "Where the light comes from and how the keys catch it."
        case .keyboard: "Keycap shape, size and what's printed on each key."
        case .sound: "Switch sounds, generated with mechsound."
        case .dock: "How Marbly stands in for the macOS Dock."
        case .permissions: "What Marbly can access, and why."
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .appearance: AppearancePage(prefs: prefs, store: store)
        case .lighting: LightingPage(prefs: prefs)
        case .keyboard: KeyboardPage(prefs: prefs)
        case .sound: SoundPage(prefs: prefs, sound: sound)
        case .dock: DockPage(prefs: prefs, permissions: permissions, page: $navigation.page)
        case .permissions: PermissionsPage(permissions: permissions)
        }
    }
}

private struct SidebarItemStyle: ButtonStyle {
    let selected: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Idle options sit back; hover brightens them; selection is indigo.
            .foregroundStyle(selected ? Radix.indigo11 : (hovering ? Radix.slate12 : Radix.slate10))
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                if selected {
                    shape.fill(Radix.indigo4)
                } else if hovering || configuration.isPressed {
                    shape.fill(Radix.slate3)
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? Motion.pressedScale : 1)
            .onHover { hovering = $0 }
            .animation(Motion.easeOut, value: hovering)
            .animation(Motion.easeOut, value: selected)
            .animation(Motion.easeOut, value: configuration.isPressed)
    }
}

/// Links out to the website, muted until hovered.
private struct SidebarFooter: View {
    private static let site = URL(string: "https://marbly.click")!
    private static let links: [(title: String, url: URL)] = [
        ("marbly.click", site),
        ("Terms", site.appendingPathComponent("terms")),
        ("Guide", site.appendingPathComponent("guide")),
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Self.links, id: \.title) { link in
                FooterLink(title: link.title, url: link.url)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

private struct FooterLink: View {
    let title: String
    let url: URL
    @State private var hovering = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button { openURL(url) } label: {
            Text(title)
                .typeStyle(.caption)
                .foregroundStyle(hovering ? Radix.slate12 : Radix.slate10)
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .animation(Motion.easeOut, value: hovering)
        .accessibilityAddTraits(.isLink)
        .help(url.absoluteString)
    }
}

/// Opacity plus a 4 pt blur, for cross-fading pages.
private struct BlurFade: ViewModifier {
    let amount: Double
    func body(content: Content) -> some View {
        content.opacity(1 - amount).blur(radius: 4 * amount)
    }
}

extension EnvironmentValues {
    /// Set by `--snapshot-settings`, which can't render a live ScrollView.
    @Entry var snapshotLayout = false
}

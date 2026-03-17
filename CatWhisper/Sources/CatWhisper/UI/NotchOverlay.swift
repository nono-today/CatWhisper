import SwiftUI
import AppKit

// MARK: - View Model

@MainActor
final class NotchPillViewModel: ObservableObject {
    enum DisplayState: Equatable {
        case hidden
        case recording
        case transcribing
        case result
    }

    @Published var displayState: DisplayState = .hidden
    @Published var resultText: String = ""
    var topPadding: CGFloat = 0
}

// MARK: - Overlay Controller

@MainActor
final class NotchOverlay {
    private var panel: NSPanel?
    let viewModel = NotchPillViewModel()
    private var hideWorkItem: DispatchWorkItem?
    private var orderOutWorkItem: DispatchWorkItem?

    func setup() {
        guard panel == nil else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let hasNotch = screen.safeAreaInsets.top > 0

        let panelWidth: CGFloat = 350
        let panelHeight: CGFloat = 120

        // Push pill down to just below the physical notch cutout
        // safeAreaInsets.top ≈ 37pt (notch ~31pt + menu bar text ~6pt)
        // We want the pill top to sit right at the notch bottom edge
        viewModel.topPadding = hasNotch ? screen.safeAreaInsets.top - 10 : 0

        let contentView = NotchPillView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.contentView = hosting

        // Position: panel top = screen top (covers notch area)
        let x = screen.frame.midX - panelWidth / 2
        let y: CGFloat
        if hasNotch {
            y = screen.frame.maxY - panelHeight
        } else {
            // Non-notch: just below menu bar
            y = screen.visibleFrame.maxY - panelHeight + 4
        }

        panel.setFrame(
            NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            display: false
        )
        self.panel = panel
    }

    func showRecording() {
        setup()
        cancelPendingHide()
        viewModel.displayState = .recording
        panel?.orderFrontRegardless()
    }

    func showTranscribing() {
        cancelPendingHide()
        viewModel.displayState = .transcribing
    }

    func showResult(_ text: String) {
        cancelPendingHide()
        viewModel.resultText = text
        viewModel.displayState = .result

        let item = DispatchWorkItem { [weak self] in
            self?.viewModel.displayState = .hidden
            let orderOut = DispatchWorkItem { [weak self] in
                self?.panel?.orderOut(nil)
            }
            self?.orderOutWorkItem = orderOut
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: orderOut)
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    func hide() {
        cancelPendingHide()
        viewModel.displayState = .hidden
        let orderOut = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        orderOutWorkItem = orderOut
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: orderOut)
    }

    private func cancelPendingHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        orderOutWorkItem?.cancel()
        orderOutWorkItem = nil
    }
}

// MARK: - SwiftUI Pill View

private struct NotchPillView: View {
    @ObservedObject var viewModel: NotchPillViewModel

    private var isVisible: Bool {
        viewModel.displayState != .hidden
    }

    var body: some View {
        VStack(spacing: 0) {
            // Push pill down to align with notch bottom edge
            if viewModel.topPadding > 0 {
                Spacer().frame(height: viewModel.topPadding)
            }

            if isVisible {
                pill
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.5, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: .top).combined(with: .opacity)
                        )
                    )
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: viewModel.displayState)
    }

    private var pill: some View {
        HStack(spacing: 10) {
            pillContent
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.black)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
    }

    @ViewBuilder
    private var pillContent: some View {
        switch viewModel.displayState {
        case .recording:
            WaveformBars()
            Text("錄音中")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("辨識中...")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        case .result:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(viewModel.resultText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        case .hidden:
            EmptyView()
        }
    }
}

// MARK: - Waveform Animation

private struct WaveformBars: View {
    @State private var isAnimating = false

    private let bars: [(low: CGFloat, high: CGFloat)] = [
        (4, 12), (4, 18), (4, 10), (4, 16), (4, 8)
    ]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<bars.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.red)
                    .frame(width: 3, height: isAnimating ? bars[i].high : bars[i].low)
            }
        }
        .frame(height: 18)
        .animation(
            .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

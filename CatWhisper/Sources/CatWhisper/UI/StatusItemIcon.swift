import SwiftUI

/// Menu bar icon — pixel art cat, switches image per state
struct StatusItemIcon: View {
    let state: AppState.State

    var body: some View {
        let name = state == .recording ? "CatRecording" : "CatIdle"
        Image(name)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
            .frame(height: 18)
    }
}

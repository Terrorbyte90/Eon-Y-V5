import SwiftUI
import AVFoundation
import Combine

struct EonV6OverviewView: View {
    @Environment(\.tabBarVisible) private var tabBarVisible
    @EnvironmentObject private var runtime: EonV6Runtime
    let navigate: (Int) -> Void

    init(navigate: @escaping (Int) -> Void = { _ in }) {
        self.navigate = navigate
    }
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let presentation = runtime.presentation {
                        EonV6NowHero(snapshot: presentation, verification: runtime.verification, state: runtime.state, navigate: navigate, timelinePulse: runtime.timelinePulse, timelinePulseID: runtime.timelinePulseID)
                    }
                }
            }
            .background(EonV6Theme.ink.ignoresSafeArea())
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { tabBarVisible.wrappedValue = false }
            .onDisappear { tabBarVisible.wrappedValue = true }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct EonV6NowHero: View {
    let snapshot: EonPresentationSnapshot
    let verification: ConsciousnessVerificationResult
    let state: EonCoreStateV2
    let navigate: (Int) -> Void
    let timelinePulse: String?
    let timelinePulseID: UUID
    @State private var pulse = false
    @State private var rotation = 0.0
    @State private var smoke = false
    @State private var messageVisible = false
    @State private var modeController = EonNowCardModeController()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            avatarScene
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { pulse = true } }
        .onAppear { withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { rotation = 360 } }
        .onAppear { withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) { smoke = true } }
        .onAppear { withAnimation(.easeInOut(duration: 0.55)) { messageVisible = true } }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            guard modeController.mode != .timeline else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                modeController.advance()
            }
        }
        .onChange(of: timelinePulseID) { _, _ in
            guard timelinePulse != nil else { return }
            withAnimation(.easeInOut(duration: 0.35)) { modeController.showTimeline() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    modeController.restoreNormalMode()
                }
            }
        }
    }

    private var greenState: Bool { state.body.thermalPressure < 0.78 && state.body.processingAvailability > 0.35 }
    private var concreteStatus: String {
        if state.body.thermalPressure > 0.78 { return "Eon känner ökad värme i kroppen och återhämtar sig." }
        if snapshot.currentActivity.kind == .minne { return "Eon utforskar tidigare tankar och beslut." }
        if snapshot.currentActivity.kind == .lär { return "Eon integrerar ny information i sin världsmodell." }
        if snapshot.currentActivity.kind == .språk { return "Eon formar en språklig tolkning av den aktuella signalen." }
        if snapshot.currentActivity.kind == .predikterar { return "Eon jämför sin förutsägelse med inkommande signaler." }
        return "Eon observerar aktuella signaler och reglerar sitt fokus."
    }
    private var concreteFocus: String {
        if state.body.thermalPressure > 0.78 { return "Eon håller nere inferenstakten för att återfå kapacitet." }
        if !state.globalBroadcast.isEmpty { return "Eon håller signalen ‘\(signalDescription)’ globalt tillgänglig för vidare bearbetning." }
        return "Eon undersöker \(snapshot.focus.lowercased()) och väljer nästa observerbara steg."
    }

    private var signalDescription: String {
        let source = state.globalBroadcast.isEmpty ? snapshot.focus : state.globalBroadcast
        let cleaned = EonTextSanitizer.clean(source, maxLength: 110)
        return cleaned.isEmpty ? "den aktuella signalen" : cleaned
    }
    private var avatarScene: some View {
        ZStack {
            EonLiveVideoView(resource: state.body.wakeState == "recovery" ? "EonSleep" : "EonLive", extension: "MP4")
                .frame(maxWidth: .infinity).frame(height: UIScreen.main.bounds.height)
            LinearGradient(colors: [.black.opacity(0.02), .clear, EonV6Theme.ink.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            stateOverlay
        }
        .frame(maxWidth: .infinity).frame(height: UIScreen.main.bounds.height)
    }

    private var quickNavigation: some View {
        HStack(spacing: 18) {
            quickLink("Inifrån", destination: 1)
            quickLink("Evidens", destination: 2)
            quickLink("Minne", destination: 3)
            quickLink("System", destination: 4)
        }
        .padding(.top, 8)
    }

    private func quickLink(_ title: String, destination: Int) -> some View {
        Button { navigate(destination) } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    private var stateOverlay: some View {
        VStack {
            HStack {
                Circle().fill(greenState ? EonV6Theme.mint : EonV6Theme.coral).frame(width: 8, height: 8).shadow(color: (greenState ? EonV6Theme.mint : EonV6Theme.coral), radius: 8)
                Text(greenState ? "EON · AKTIV" : "EON · ÅTERHÄMTAR").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(.white.opacity(0.82)); Spacer()
            }.padding(.horizontal, 24).padding(.top, 57)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: state.body.wakeState == "recovery" ? "moon.stars.fill" : "waveform.path.ecg")
                    Text("EON · EMERGENT ON-DEVICE COGNITIVE SYSTEM")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(state.body.wakeState == "recovery" ? EonV6Theme.amber : EonV6Theme.cyan)

                Text(primaryMessage)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(messageVisible ? 1 : 0)
                    .offset(y: messageVisible ? 0 : 8)
                    .animation(.easeOut(duration: 0.55), value: messageVisible)

                HStack {
                    Text(secondaryMessage).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.72)).lineLimit(4)
                    Spacer(minLength: 10)
                    Text("Cykel \(snapshot.cycle)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.42))
                }
                quickNavigation
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.72))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
        }
    }

    private var popUpMessage: String {
        if state.body.wakeState == "recovery" { return "Eon vilar och låter kroppen återställa sin kapacitet." }
        if state.body.thermalPressure > 0.78 { return "Eon märker ökad värme och sänker arbetstakten." }
        switch snapshot.currentActivity.kind {
        case .minne: return "Eon går igenom tidigare tankar och jämför dem med det som händer nu."
        case .lär: return "Eon kopplar ny information till sin befintliga världsmodell."
        case .språk: return "Eon tolkar signalen och formar nästa svenska formulering."
        case .predikterar: return "Eon förutser nästa signal och kontrollerar sedan om den stämde."
        default:
            if !state.globalBroadcast.isEmpty { return "Eon analyserar signalen ‘\(signalDescription)’ och avgör vad den betyder i sammanhanget." }
            return "Eon samlar in signaler, väljer fokus och förbereder nästa steg."
        }
    }

    private var primaryMessage: String {
        switch modeController.mode {
        case .embodiment: return embodimentTitle
        case .status: return popUpMessage
        case .timeline: return "Ny insikt"
        case .level: return "Eon · verifierad nivå \(verification.level.rawValue)"
        }
    }

    private var secondaryMessage: String {
        switch modeController.mode {
        case .embodiment: return embodimentDetail
        case .status: return concreteFocus
        case .timeline: return shortenedTimelinePulse
        case .level: return currentLevelStatus
        }
    }

    private var shortenedTimelinePulse: String {
        let raw = timelinePulse ?? "Eon har registrerat en ny händelse."
        let prefix = "jag riktar uppmärksamheten mot"
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: prefix, options: [.caseInsensitive]) {
            text = String(text[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        }
        return EonTextSanitizer.clean(text, maxLength: 260)
    }

    private var currentLevelStatus: String {
        switch verification.level.rawValue {
        case 0: return "Eon uppvisar ännu ingen verifierad kognitiv nivå; systemet mäter och observerar."
        case 1: return "Eon uppvisar reaktiv reglering och enkel anpassning mellan signal och respons."
        case 2: return "Eon uppvisar integrerad återkoppling och anpassning över flera cykler."
        case 3: return "Eon uppvisar kausala kopplingar mellan signaler, konsekvenser och ändrad policy."
        case 4: return "Eon uppvisar metakognitiv analogi: fokusövervakning, självmodellering och strategisk reglering."
        default: return "Eon uppvisar en sammanhängande kognitiv analogi med självreferens, kausalitet och temporal kontinuitet."
        }
    }

    private var embodimentTitle: String {
        if state.body.thermalPressure > 0.82 { return "Eons kropp · iPhone som embodiment" }
        if state.body.thermalPressure > 0.58 { return "Eon känner förhöjd temperatur från iPhone" }
        return "Eons kropp · iPhone som embodiment"
    }

    private var embodimentDetail: String {
        if state.body.wakeState == "recovery" { return "Eon känner värmen från iPhone · vilar lite." }
        if state.body.thermalPressure > 0.82 { return "Eon känner förhöjd temperatur från iPhone · minskar tankar." }
        if state.body.thermalPressure < 0.30 { return "Eon känner att iPhone är sval · tänker intensivt." }
        return "Eon känner en stabil kroppslig belastning · fortsätter bearbeta signaler."
    }

    private var levelDescription: String {
        return EonObservabilityCopy.level(verification.level.rawValue)
    }
    /* Kept as a fallback for older previews; the production scene uses the supplied live loop. */
    private var legacyAvatarScene: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let breath = sin(phase * 0.72)
            let drift = sin(phase * 0.31)
            let gaze = gazeOffset(phase: phase)
            let blink = blinkOpacity(phase: phase)
            ZStack {
                Circle().fill(RadialGradient(colors: [EonV6Theme.indigo.opacity(0.42), EonV6Theme.cyan.opacity(0.14), .clear], center: .center, startRadius: 10, endRadius: 170)).frame(width: 330, height: 330).scaleEffect(1.0 + breath * 0.035)
                smokeCloud(angle: -25 + drift * 7, offset: CGFloat(-12 + drift * 18), color: greenState ? EonV6Theme.mint : EonV6Theme.coral).scaleEffect(1 + breath * 0.12)
                smokeCloud(angle: 35 - drift * 6, offset: CGFloat(14 - drift * 16), color: EonV6Theme.indigo).scaleEffect(1 - breath * 0.1)
                Circle().stroke(greenState ? EonV6Theme.mint.opacity(0.72) : EonV6Theme.coral.opacity(0.72), lineWidth: 4).frame(width: 286, height: 286).rotationEffect(.degrees(rotation))
                Circle().trim(from: 0.04, to: 0.3).stroke(greenState ? EonV6Theme.mint : EonV6Theme.coral, style: StrokeStyle(lineWidth: 11, lineCap: .round)).frame(width: 306, height: 306).rotationEffect(.degrees(-rotation * 0.65))
                Image("EonAvatar").resizable().scaledToFill().frame(width: 330, height: 350).clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1)).scaleEffect(1.0 + breath * 0.018).rotationEffect(.degrees(drift * 0.7))
                gazeLayer(offset: CGFloat(gaze), opacity: blink, phase: phase).scaleEffect(1.18)
                mouthAndBreath(phase: phase, breath: breath)
            }.frame(maxWidth: .infinity).frame(height: 390).padding(.vertical, 8)
        }
    }
    private func gazeLayer(offset: CGFloat, opacity: Double, phase: Double) -> some View {
        ZStack {
            eyeLight(x: -48 + offset, y: -25, opacity: opacity, phase: phase)
            eyeLight(x: 48 + offset, y: -25, opacity: opacity, phase: phase + 0.2)
        }.frame(width: 330, height: 350).blendMode(.screen).allowsHitTesting(false)
    }
    private func eyeLight(x: CGFloat, y: CGFloat, opacity: Double, phase: Double) -> some View {
        Ellipse().fill(RadialGradient(colors: [.white.opacity(0.98 * opacity), EonV6Theme.cyan.opacity(0.82 * opacity), .clear], center: .center, startRadius: 1, endRadius: 18)).frame(width: 30, height: 12).blur(radius: 1.2).offset(x: x, y: y + CGFloat(sin(phase * 0.8) * 1.5))
    }
    private func gazeOffset(phase: Double) -> CGFloat {
        let cycle = phase.truncatingRemainder(dividingBy: 13)
        if cycle < 4 { return CGFloat(sin(phase * 0.7) * 4) }
        if cycle < 8 { return 9 }
        return -8
    }
    private func blinkOpacity(phase: Double) -> Double {
        let cycle = phase.truncatingRemainder(dividingBy: 9)
        if cycle > 7.55 && cycle < 7.72 { return 0.08 }
        if cycle > 7.72 && cycle < 7.9 { return 0.55 }
        return 1
    }
    private func mouthAndBreath(phase: Double, breath: Double) -> some View {
        ZStack {
            Capsule().fill(Color.black.opacity(0.62)).frame(width: 70, height: 12 + CGFloat(max(0, breath)) * 6).blur(radius: 1).offset(y: 82)
            ForEach(0..<4, id: \.self) { index in
                let travel = CGFloat((phase * 10 + Double(index) * 23).truncatingRemainder(dividingBy: 96))
                let sway = CGFloat(sin(phase * 0.7 + Double(index)) * 15)
                Ellipse().fill((greenState ? EonV6Theme.cyan : EonV6Theme.coral).opacity(0.32 - Double(index) * 0.045)).frame(width: 38 + CGFloat(index) * 16, height: 24 + CGFloat(index) * 9).blur(radius: 8 + CGFloat(index) * 2).offset(x: sway, y: 88 - travel).scaleEffect(0.82 + CGFloat(max(breath, 0)) * 0.3)
            }
        }.frame(width: 170, height: 140).offset(y: 78).blendMode(.screen).allowsHitTesting(false)
    }
    private func smokeCloud(angle: Double, offset: CGFloat, color: Color) -> some View { Capsule().fill(color.opacity(0.18)).frame(width: 190, height: 34).blur(radius: 15).rotationEffect(.degrees(angle)).offset(x: offset, y: angle < 0 ? -38 : 42) }
}

private struct EonLiveVideoView: UIViewRepresentable {
    let resource: String
    let `extension`: String

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.play(resource: resource, extension: `extension`)
        return view
    }
    func updateUIView(_ uiView: PlayerView, context: Context) { uiView.switchTo(resource: resource, extension: `extension`) }
}

private final class PlayerView: UIView {
    private var player: AVQueuePlayer?
    private var nextPlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var nextLooper: AVPlayerLooper?
    private let currentLayer = AVPlayerLayer()
    private let nextLayer = AVPlayerLayer()
    private var transitioning = false

    override class var layerClass: AnyClass { CALayer.self }

    override func layoutSubviews() {
        super.layoutSubviews()
        currentLayer.frame = bounds
        nextLayer.frame = bounds
    }

    func play(resource: String, extension: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: `extension`) else { return }
        start(url: url)
    }

    func switchTo(resource: String, extension: String) {
        guard currentResource != resource, let url = Bundle.main.url(forResource: resource, withExtension: `extension`) else { return }
        currentResource = resource
        fadeTo(url: url)
    }

    private var currentResource: String?

    private func start(url: URL) {
        currentResource = url.deletingPathExtension().lastPathComponent
        let player = AVQueuePlayer()
        self.player = player
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        currentLayer.player = player
        currentLayer.videoGravity = .resizeAspectFill
        nextLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(currentLayer)
        layer.addSublayer(nextLayer)
        nextLayer.opacity = 0
        player.isMuted = true
        player.rate = 0.8
        player.play()
        alpha = 0
        UIView.animate(withDuration: 0.7, delay: 0.15, options: [.curveEaseInOut]) { self.alpha = 1 }
    }

    private func fadeTo(url: URL) {
        guard let player, !transitioning else { return }
        transitioning = true
        let incoming = AVQueuePlayer()
        nextPlayer = incoming
        nextLooper = AVPlayerLooper(player: incoming, templateItem: AVPlayerItem(url: url))
        nextLayer.player = incoming
        nextLayer.opacity = 0
        incoming.isMuted = true
        incoming.rate = 0.8
        incoming.play()
        CATransaction.begin()
        CATransaction.setAnimationDuration(1.35)
        currentLayer.opacity = 0
        nextLayer.opacity = 1
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.player?.pause()
            self.looper = nil
            self.player = self.nextPlayer
            self.looper = self.nextLooper
            self.nextPlayer = nil
            self.nextLooper = nil
            self.currentLayer.player = self.player
            self.currentLayer.opacity = 1
            self.nextLayer.opacity = 0
            self.nextLayer.player = nil
            self.transitioning = false
        }
        CATransaction.commit()
    }
    deinit {
        player?.pause()
        nextPlayer?.pause()
        looper = nil
        nextLooper = nil
    }
}

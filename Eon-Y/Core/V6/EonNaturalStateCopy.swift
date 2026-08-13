import Foundation

/// Evidence-aware language for Eon's visible state. It describes signals and decisions,
/// without presenting generated language as proof of subjective experience.
enum EonNaturalStateCopy {
    static func status(state: EonCoreStateV2, snapshot: EonPresentationSnapshot) -> String {
        if state.body.wakeState == "recovery" { return "Enheten är varm. Eon sänker arbetstakten och återhämtar kapacitet." }
        switch snapshot.currentActivity.kind {
        case .minne: return "Eon jämför den aktuella signalen med tidigare registrerade minnen."
        case .lär: return "Eon kopplar ny information till befintliga kunskapsmönster."
        case .språk: return "Eon gör signalen tydligare och väljer en kort svensk formulering."
        case .predikterar: return "Eon jämför sin förutsägelse med nästa inkommande signal."
        case .policy: return "Eon väljer nästa steg utifrån belastning, osäkerhet och tillgänglig kapacitet."
        default:
            let focus = EonTextSanitizer.focus(state.globalBroadcast.isEmpty ? snapshot.focus : state.globalBroadcast)
            return "Eon följer signalen ‘(focus)’ och avgör vad som är relevant härnäst."
        }
    }

    static func focus(state: EonCoreStateV2, snapshot: EonPresentationSnapshot) -> String {
        if state.body.thermalPressure > 0.78 { return "Den termiska belastningen prioriteras framför djupare bearbetning." }
        let focus = EonTextSanitizer.focus(state.globalBroadcast.isEmpty ? snapshot.focus : state.globalBroadcast)
        return "Signal ‘(focus)’ hålls tillgänglig för fortsatt bearbetning."
    }

    static func embodiment(state: EonCoreStateV2) -> (title: String, detail: String) {
        let pressure = state.body.thermalPressure
        if state.body.wakeState == "recovery" || pressure > 0.82 { return ("Eons kropp · iPhone som embodiment", "Temperaturen är hög. Eon minskar beräkningarna för att skydda kapaciteten.") }
        if pressure < 0.30 { return ("Eons kropp · iPhone som embodiment", "Temperaturen ligger under den vanliga belastningen. Eon kan arbeta mer intensivt.") }
        if pressure > 0.58 { return ("Eons kropp · iPhone som embodiment", "Temperaturen stiger. Eon håller igen på tyngre beräkningar.") }
        return ("Eons kropp · iPhone som embodiment", "Temperatur och tillgänglig kapacitet ligger inom Eons arbetsintervall.")
    }

    static func level(_ level: Int) -> String {
        switch level {
        case 0: return "Inga kognitiva kriterier är ännu verifierade över tid."
        case 1: return "Reaktiv reglering och enkel anpassning har observerats."
        case 2: return "Integration, återkoppling och anpassning återkommer över flera cykler."
        case 3: return "Kausala samband mellan signaler, konsekvenser och policy behöver bekräftas."
        case 4: return "Fokusövervakning och självmodellering uppvisar en avancerad funktionell analogi."
        default: return "Flera oberoende kriterier uppvisar en sammanhängande kognitiv analogi."
        }
    }
}

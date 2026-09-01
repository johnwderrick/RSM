import SwiftUI

struct LegendsPlayerComparisonView: View {
    let store: LegendsStore
    let primary: LegendsCard
    @Environment(\.dismiss) private var dismiss
    @State private var secondaryID: String?

    private var candidates: [LegendsCard] {
        store.activeClubPlayers.filter { $0.id != primary.id }.sorted {
            store.effectiveOverall(for: $0) > store.effectiveOverall(for: $1)
        }
    }

    private var secondary: LegendsCard? {
        if let secondaryID { return candidates.first { $0.id == secondaryID } }
        let samePosition = candidates.first { store.canPlay($0, in: primary.position) }
        return samePosition ?? candidates.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    comparisonHeader
                    if let secondary { comparisonCards(secondary) }
                    else { Text("Sign another player to compare careers.").foregroundStyle(LegendsPalette.navy.opacity(0.65)).padding(30) }
                }
                .padding(16)
            }
            .background(LegendsPalette.contentBackground)
            .navigationTitle("COMPARE PLAYERS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .accessibilityIdentifier("legends.playerComparison")
    }

    private var comparisonHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAREER OUTLOOK").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.blue)
            Text("Compare current ability and career timing without changing either player.")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparisonCards(_ other: LegendsCard) -> some View {
        VStack(spacing: 10) {
            Picker("Compare with", selection: Binding(get: { secondaryID ?? other.id }, set: { secondaryID = $0 })) {
                ForEach(candidates) { card in Text(card.name).tag(card.id) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("legends.playerComparison.selection")
            HStack(alignment: .top, spacing: 10) {
                column(primary)
                column(other)
            }
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func column(_ card: LegendsCard) -> some View {
        VStack(spacing: 8) {
            PlayerPortraitView(name: card.name, position: card.position.broad, nation: card.nation, size: 62).clipShape(Circle())
            Text(card.name).font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(LegendsPalette.navy).lineLimit(1)
            let signed = store.isSigned(card)
            metric("STATUS", signed ? "SIGNED" : "UNSIGNED")
            metric("AGE", "\(store.effectiveAge(for: card))")
            metric("OVR", "\(store.effectiveOverall(for: card))")
            metric("POSITION", card.position.rawValue)
            metric("ARCHETYPE", store.identityProfile(for: card).identity.archetype.rawValue)
            metric("PROFILE", store.careerState(for: card)?.lifecycleProfile.rawValue ?? "NOT ACTIVE")
            metric("STAGE", signed ? (store.isFinalSeason(card) ? "FINAL SEASON" : "ACTIVE") : "UNSIGNED")
            let detailed = store.effectiveDetailedAttributes(for: card)
            metric("FINISHING", "\(detailed.finishing)")
            metric("PASSING", "\(detailed.passing)")
            metric("VISION", "\(detailed.vision)")
            metric("TEAMWORK", "\(detailed.teamwork)")
            if let career = store.careerState(for: card) {
                metric("PRIME", "\(career.peakStartAge)–\(career.peakEndAge)")
                metric("RETIREMENT", "AGE \(career.intendedRetirementAge)")
                metric("SEASONS", "\(max(0, store.profile.currentSeason - career.signedSeason))")
                metric("APPEARANCES", "\(career.appearances)")
                let condition = store.condition(for: card)
                metric("FORM / MORALE", "\(condition.form) / \(condition.morale)")
                metric("TEAMWORK", "\(condition.teamwork)")
                metric("FAME", "\(condition.fame)")
            }
            metric("FAVOURITE", store.isFavourite(card.id) ? "YES" : "NO")
        }
        .frame(maxWidth: .infinity)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.navy.opacity(0.5))
            Text(value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(LegendsPalette.navy).multilineTextAlignment(.center)
        }
    }
}

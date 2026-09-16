import SwiftUI

/// Cosmetic badge selection for the user's Legends club. The chosen artwork
/// is stored on `LegendsProfile`; it has no effect on ratings, economy or match
/// outcomes and is available without a cost or unlock requirement.
struct LegendsClubBadgeView: View {
    let store: LegendsStore
    var onNavigate: ((LegendsNavItem) -> Void)? = nil
    var onBack: () -> Void

    @State private var feedback: String?

    var body: some View {
        LegendsMenuShell(
            store: store,
            title: "CLUB BADGE",
            subtitle: "CHOOSE YOUR CLUB IDENTITY",
            icon: "shield.lefthalf.filled",
            accent: LegendsPalette.purple,
            onBack: onBack,
            currentNav: .club,
            onNavigate: onNavigate,
            headerBackTitle: "Back to Club",
            onHeaderBack: { onNavigate?(.club) }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                currentBadge

                if let feedback {
                    Text(feedback)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(LegendsPalette.navy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LegendsPalette.greenWash)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("legends.badge.feedback")
                }

                Text("CHOOSE A BADGE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                    ForEach(1...ClubBadgeCatalog.count, id: \.self) { index in
                        badgeOption(index)
                    }
                }
                .accessibilityIdentifier("legends.badge.grid")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("legends.badge.screen")
        }
    }

    private var currentBadge: some View {
        HStack(spacing: 16) {
            ClubBadgeView(
                name: store.profile.clubName,
                shortName: store.profile.crestShort,
                size: 82,
                primaryColor: Color(rgb: store.profile.crestColorRGB),
                badgeIndex: store.resolvedCrestBadgeIndex
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(store.profile.clubName.uppercased())
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(LegendsPalette.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("CURRENT BADGE · \(store.resolvedCrestBadgeIndex) OF \(ClubBadgeCatalog.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(LegendsPalette.purple)
                Text("Tap any badge below to apply it. Your choice saves immediately and remains after relaunching the game.")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(LegendsPalette.navy.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LegendsPalette.purple.opacity(0.35), lineWidth: 1.2))
        .shadow(color: LegendsPalette.navy.opacity(0.09), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legends.badge.current")
        .accessibilityLabel("Current club badge \(store.resolvedCrestBadgeIndex) of \(ClubBadgeCatalog.count)")
    }

    private func badgeOption(_ index: Int) -> some View {
        let selected = index == store.resolvedCrestBadgeIndex
        return Button {
            Haptics.tap()
            store.setCrestBadge(index: index)
            feedback = "BADGE \(index) SAVED"
        } label: {
            VStack(spacing: 8) {
                ClubBadgeView(
                    name: store.profile.clubName,
                    shortName: store.profile.crestShort,
                    size: 64,
                    primaryColor: Color(rgb: store.profile.crestColorRGB),
                    badgeIndex: index
                )
                Text(selected ? "SELECTED" : "BADGE \(index)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(selected ? LegendsPalette.purple : LegendsPalette.navy.opacity(0.68))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(selected ? LegendsPalette.purpleWash : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? LegendsPalette.purple : LegendsPalette.navy.opacity(0.10), lineWidth: selected ? 2.5 : 1)
            )
            .shadow(color: LegendsPalette.navy.opacity(selected ? 0.12 : 0.06), radius: 6, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("legends.badge.option.\(index)")
        .accessibilityLabel("Badge \(index)" + (selected ? ", selected" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

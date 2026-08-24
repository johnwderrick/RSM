import SwiftUI

struct LegendsManagerOnboardingView: View {
    let store: LegendsStore
    let onComplete: () -> Void
    @State private var archetype: LegendsManagerArchetype?
    @State private var step = 0
    @State private var firstName = ""
    @State private var surname = ""
    @State private var nationality = "England"
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -38, to: Date()) ?? Date()

    private var cleanFirstName: String { LegendsManagerIdentityValidation.cleanName(firstName) }
    private var cleanSurname: String { LegendsManagerIdentityValidation.cleanName(surname) }
    private var namesValid: Bool {
        LegendsManagerIdentityValidation.validName(cleanFirstName) && LegendsManagerIdentityValidation.validName(cleanSurname)
    }
    private var dateValid: Bool { LegendsManagerIdentityValidation.validDateOfBirth(dateOfBirth) }

    var body: some View {
        ZStack {
            LegendsPalette.navy.ignoresSafeArea()
            Group {
                switch step {
                case 0: selection
                case 1: customization
                default: confirmation
                }
            }
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var selection: some View {
        // A plain VStack left the "SELECT MANAGER" button unreachable on a
        // landscape iPhone once a profile was picked: heading + the 226pt
        // card row + the detail panel + button together exceed the ~402pt
        // of landscape height, and with no scroll container the button was
        // simply clipped off-screen — the same failure class fixed earlier
        // for the post-match Continue button. The horizontal card ScrollView
        // nests fine inside this vertical one; SwiftUI resolves the gesture
        // axes independently.
        ScrollView {
            VStack(spacing: 14) {
                heading("CHOOSE YOUR MANAGER", subtitle: "Choose the football philosophy that will define your journey.")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(LegendsManagerArchetype.allCases) { option in
                            archetypeCard(option)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                if let selected = archetype {
                    detailPanel(selected)
                    Button("SELECT MANAGER") { step = 1 }
                        .buttonStyle(IdentityPrimaryButtonStyle(color: selected.accent))
                        .disabled(archetype == nil)
                } else {
                    Text("SELECT A PROFILE TO CONTINUE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(18)
        }
    }

    private func archetypeCard(_ option: LegendsManagerArchetype) -> some View {
        let selected = archetype == option
        return Button {
            Haptics.tap()
            archetype = option
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [option.accent.opacity(0.95), LegendsPalette.navy], startPoint: .top, endPoint: .bottom)
                    managerArtwork(option, fullBody: true)
                        .padding(.top, 8)
                }
                .frame(width: 142, height: 226)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? .white : option.accent.opacity(0.55), lineWidth: selected ? 3 : 1))
                Text(option.nickname.rawValue)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(option.philosophy)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(option.accent)
            }
            .scaleEffect(selected ? 1.04 : 0.96)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(option.nickname.rawValue). \(option.philosophy) manager. Preferred formation \(option.formation).")
    }

    private func detailPanel(_ option: LegendsManagerArchetype) -> some View {
        HStack(spacing: 12) {
            managerArtwork(option, fullBody: false)
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(option.accent, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(option.nickname.rawValue).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("\(option.philosophy) · \(option.formation) · \(option.trait.rawValue)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(option.accent)
                Text(option.description)
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.72)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var customization: some View {
        // Fits without a keyboard up, but on a landscape phone the software
        // keyboard covers a large fraction of the ~402pt height once a text
        // field is focused, and with no scroll container REVIEW PROFILE can
        // end up hidden behind it with no way to reach it — confirmed via a
        // real end-to-end UI test (typing into both fields, keyboard up,
        // then unable to hit-test REVIEW PROFILE). Same fix as the other
        // two onboarding steps.
        ScrollView {
            VStack(spacing: 16) {
                heading("CREATE YOUR MANAGER", subtitle: "Your name leads the story. The archetype defines the starting identity.")
                if let selected = archetype {
                    HStack(spacing: 14) {
                        managerArtwork(selected, fullBody: false).frame(width: 92, height: 92).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selected.nickname.rawValue).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                            Text("\(selected.philosophy) · \(selected.formation)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(selected.accent)
                        }
                    }
                }
                HStack(spacing: 12) {
                    identityField("FIRST NAME", text: $firstName)
                    identityField("SURNAME", text: $surname)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NATIONALITY").identityLabel()
                        Picker("Nationality", selection: $nationality) {
                            ForEach(Self.nations, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DATE OF BIRTH").identityLabel()
                        DatePicker("Date of Birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(.white)
                            .padding(4)
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                if !namesValid { Text("Enter a first name and surname using letters, apostrophes or hyphens.").identityError() }
                if !dateValid { Text("Manager age must be between 25 and 70.").identityError() }
                HStack {
                    Button("BACK") { step = 0 }.buttonStyle(IdentitySecondaryButtonStyle())
                    Button("REVIEW PROFILE") { step = 2 }.buttonStyle(IdentityPrimaryButtonStyle(color: archetype?.accent ?? LegendsPalette.green)).disabled(!namesValid || !dateValid || archetype == nil)
                }
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func identityField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).identityLabel()
            TextField(title, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(10)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity)
    }

    private var confirmation: some View {
        // Same landscape-height risk as `selection`: heading + a 120pt
        // portrait row + a summary row + description + the button row adds
        // up to more than the ~402pt of landscape height on a phone, which
        // would clip "BEGIN YOUR LEGEND" off-screen exactly like the
        // "SELECT MANAGER" button was. Wrapped defensively for the same reason.
        ScrollView {
            VStack(spacing: 13) {
                heading("YOUR MANAGER", subtitle: "Everything is ready. Confirm to begin your Legends journey.")
                if let selected = archetype {
                    HStack(spacing: 18) {
                        managerArtwork(selected, fullBody: false).frame(width: 120, height: 120).clipShape(Circle()).overlay(Circle().stroke(selected.accent, lineWidth: 3))
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\(cleanFirstName) \(cleanSurname)".uppercased()).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white)
                            Text("\"\(selected.nickname.rawValue)\"").font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(selected.accent)
                            Text("\(nationality) · AGE \(LegendsManagerProfile(firstName: cleanFirstName, surname: cleanSurname, nationalityCode: nationality, dateOfBirth: dateOfBirth, archetype: selected).age())")
                                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    HStack(spacing: 25) {
                        summaryValue("STYLE", selected.philosophy)
                        summaryValue("FORMATION", selected.formation)
                        summaryValue("TRAIT", selected.trait.rawValue)
                    }
                    Text(selected.description).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center).frame(maxWidth: 600)
                    HStack {
                        Button("BACK") { step = 1 }.buttonStyle(IdentitySecondaryButtonStyle())
                        Button("BEGIN YOUR LEGEND") { confirm() }.buttonStyle(IdentityPrimaryButtonStyle(color: selected.accent))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryValue(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(title).identityLabel(); Text(value).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white) }
    }

    private func confirm() {
        guard let selected = archetype else { return }
        store.profile.managerProfile = LegendsManagerProfile(firstName: cleanFirstName, surname: cleanSurname, nationalityCode: nationality, dateOfBirth: dateOfBirth, archetype: selected)
        store.persist()
        Haptics.success()
        onComplete()
    }

    @ViewBuilder private func managerArtwork(_ option: LegendsManagerArchetype, fullBody: Bool) -> some View {
        let asset = fullBody ? option.fullBodyAsset : option.portraitAsset
        if UIImage(named: asset) != nil {
            // scaledToFill, not scaledToFit — the source photos aren't
            // square (portraits ~4:5, full-body ~1:2), so scaledToFit left
            // gaps at the frame's edges inside every circle/rounded-rect
            // clip that shows this artwork, letting the panel background
            // show through as a stray crescent/band. Every call site
            // already pairs this with its own .frame(...).clipShape(...),
            // which crops the overflow correctly once this actually fills.
            Image(asset).resizable().scaledToFill()
        } else {
            Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.white.opacity(0.8)).padding(18)
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text("RSM LEGENDS").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(LegendsPalette.green)
            Text(title).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
        }
    }

    private static let nations = ["England", "Scotland", "Wales", "Republic of Ireland", "France", "Germany", "Italy", "Spain", "Portugal", "Netherlands", "Brazil", "Argentina", "Japan", "South Korea"]
}

private struct IdentityPrimaryButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white).padding(.horizontal, 22).padding(.vertical, 12).background(color).clipShape(Capsule()).scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
private struct IdentitySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.82)).padding(.horizontal, 18).padding(.vertical, 11).background(.white.opacity(0.12)).clipShape(Capsule()).scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
private extension Text {
    func identityLabel() -> some View { self.font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.65)) }
    func identityError() -> some View { self.font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.orange) }
}

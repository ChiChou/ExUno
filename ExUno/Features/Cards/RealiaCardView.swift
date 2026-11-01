import SwiftUI

struct RealiaCardView: View {
    @Environment(StudyProgress.self) private var progress
    let realia: Realia
    let showAnswer: Bool
    let reveal: () -> Void

    var body: some View {
        let s = progress.strings
        ScrollView {
            VStack(spacing: 16) {
                Tag(text: s.realLife)
                RealiaObject(realia: realia).padding(.top, 4)
                Text(realia.question).font(Theme.display(19, weight: .semibold))
                if showAnswer {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text(realia.answer).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.green).multilineTextAlignment(.center)
                            SpeakButton(text: realia.speech)
                        }
                        if let alt = realia.alternative, !alt.isEmpty {
                            Text(alt).font(.subheadline).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
                                .padding(10).frame(maxWidth: .infinity)
                                .background(Theme.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                } else {
                    Button(s.howToSay, action: reveal).buttonStyle(Pill(style: .ghost, compact: true)).padding(.top, 10)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.rule, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.10), radius: 20, y: 10)
    }
}

/// Draws the physical object: a receipt, a clock face, a ticket, a price tag, an inscription…
struct RealiaObject: View {
    let realia: Realia
    private let paper = Color(red: 0.98, green: 0.98, blue: 0.96)
    private let inkColor = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        switch realia.kind {
        case .receipt: receipt
        case .clock: ClockFace(hour: realia.hour, minute: realia.minute).frame(width: 180, height: 180)
        case .ticket: ticket
        case .priceTag: priceTag
        case .contact: contact
        case .museum: museum
        case .elevator: elevator
        case .pharmacy: pharmacy
        case .inscription: inscription
        case .calendarStone: calendarStone
        }
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(realia.title).frame(maxWidth: .infinity).fontWeight(.semibold).tracking(1.5).padding(.bottom, 4)
            Rectangle().fill(.black.opacity(0.35)).frame(height: 1)
            ForEach(Array(realia.lines.enumerated()), id: \.offset) { _, line in HStack { Text(line.0); Spacer(); Text(line.1) } }
            Rectangle().fill(.black.opacity(0.35)).frame(height: 1).padding(.top, 4)
            if let f = realia.footer { HStack { Text(f.0); Spacer(); Text(f.1) }.font(Theme.mono(16, weight: .bold)).padding(.top, 2) }
        }
        .font(Theme.mono(13, weight: .regular)).foregroundStyle(inkColor)
        .padding(16).frame(width: 250)
        .background(paper).clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private var ticket: some View {
        let navy = Color(red: 0.10, green: 0.16, blue: 0.29)
        return VStack(spacing: 0) {
            Text(realia.subtitle).frame(maxWidth: .infinity, alignment: .leading)
                .font(Theme.mono(11, weight: .semibold)).tracking(1).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8).background(navy)
            VStack(alignment: .leading, spacing: 6) {
                Text(realia.title).font(Theme.display(16))
                ForEach(Array(realia.lines.enumerated()), id: \.offset) { i, line in
                    HStack { Text(line.0); Spacer(); Text(line.1).font(Theme.mono(i == 0 ? 19 : 13, weight: i == 0 ? .semibold : .regular)) }
                }
            }
            .font(Theme.mono(12, weight: .regular)).padding(12)
        }
        .foregroundStyle(navy).frame(width: 290)
        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(navy, lineWidth: 2))
    }

    private var priceTag: some View {
        VStack(spacing: 4) {
            Text(realia.title).font(Theme.display(18))
            Text(realia.subtitle).font(Theme.mono(12, weight: .regular)).foregroundStyle(.secondary)
            Text(realia.big).font(Theme.mono(34, weight: .semibold))
        }
        .foregroundStyle(inkColor).padding(14).frame(width: 220).background(Color.white)
        .overlay(alignment: .top) { Rectangle().fill(Color(red: 0.79, green: 0.20, blue: 0.17)).frame(height: 10) }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private var contact: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: realia.subtitle)
            Text(realia.title).font(Theme.display(17))
            Text(realia.big).font(Theme.mono(22)).tracking(1)
        }
        .padding(16).frame(width: 270, alignment: .leading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var museum: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(realia.title.uppercased()).font(.system(size: 12, weight: .bold)).tracking(1)
            Text(realia.subtitle).font(.system(size: 18, weight: .medium, design: .serif)).italic()
            Text(realia.big).font(Theme.mono(14, weight: .regular)).padding(.top, 4)
        }
        .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.13))
        .padding(14).frame(width: 270, alignment: .leading)
        .background(Color(red: 0.93, green: 0.91, blue: 0.88)).clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }

    private var elevator: some View {
        VStack(spacing: 10) {
            Text(realia.title).font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.7))
            Text(realia.big).font(Theme.mono(40, weight: .semibold)).tracking(2)
                .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.18))
                .padding(.horizontal, 18).padding(.vertical, 4)
                .background(Color(red: 0.04, green: 0.05, blue: 0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14).frame(width: 150)
        .background(Color(red: 0.17, green: 0.18, blue: 0.21), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pharmacy: some View {
        VStack(spacing: 2) {
            Text(realia.title).font(Theme.display(12, weight: .bold)).tracking(2).opacity(0.9)
            Text(realia.big).font(Theme.mono(40, weight: .semibold))
        }
        .foregroundStyle(.white).padding(14).frame(width: 220)
        .background(Color(red: 0.05, green: 0.42, blue: 0.29), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Carved capitals on travertine.
    private var inscription: some View {
        let stone = Color(red: 0.88, green: 0.85, blue: 0.79)
        let carve = Color(red: 0.30, green: 0.27, blue: 0.23)
        return VStack(spacing: 8) {
            Text(realia.title).font(.system(size: 20, weight: .semibold, design: .serif)).tracking(4)
            Text(realia.subtitle).font(.system(size: 11, weight: .medium, design: .serif)).tracking(2).multilineTextAlignment(.center)
            Rectangle().fill(carve.opacity(0.4)).frame(width: 120, height: 1)
            Text(realia.big).font(.system(size: 28, weight: .semibold, design: .serif)).tracking(5)
        }
        .foregroundStyle(carve).padding(.vertical, 18).padding(.horizontal, 14).frame(width: 280)
        .background(stone, in: RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    /// A Roman calendar fragment (fasti) with today's reckoning.
    private var calendarStone: some View {
        let stone = Color(red: 0.86, green: 0.83, blue: 0.76)
        let carve = Color(red: 0.32, green: 0.26, blue: 0.20)
        return VStack(spacing: 6) {
            Text("FASTI").font(.system(size: 11, weight: .semibold, design: .serif)).tracking(4).opacity(0.7)
            Text(realia.title).font(.system(size: 22, weight: .semibold, design: .serif)).tracking(2).multilineTextAlignment(.center)
            Text(realia.big).font(Theme.mono(13, weight: .regular)).opacity(0.7)
        }
        .foregroundStyle(carve).padding(16).frame(width: 260)
        .background(stone, in: RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

struct ClockFace: View {
    let hour: Int
    let minute: Int
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 3
            let ink = Theme.ink
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Theme.surface))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(ink), lineWidth: 3)
            for i in 0..<12 {
                let a = Double(i) * .pi / 6
                var p = Path()
                p.move(to: CGPoint(x: c.x + (r - 12) * sin(a), y: c.y - (r - 12) * cos(a)))
                p.addLine(to: CGPoint(x: c.x + (r - 4) * sin(a), y: c.y - (r - 4) * cos(a)))
                ctx.stroke(p, with: .color(ink), lineWidth: 2)
            }
            let ha = (Double(hour % 12) + Double(minute) / 60) * .pi / 6
            let ma = Double(minute) * .pi / 30
            var hp = Path(); hp.move(to: c); hp.addLine(to: CGPoint(x: c.x + r * 0.5 * sin(ha), y: c.y - r * 0.5 * cos(ha)))
            ctx.stroke(hp, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            var mp = Path(); mp.move(to: c); mp.addLine(to: CGPoint(x: c.x + r * 0.78 * sin(ma), y: c.y - r * 0.78 * cos(ma)))
            ctx.stroke(mp, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(Theme.amber))
        }
        .accessibilityLabel(String(format: "%d:%02d", hour, minute))
    }
}

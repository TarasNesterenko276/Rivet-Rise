import SwiftUI

/// The site log: a clipboard with the lifetime record card, a hard hat covered in
/// achievement stickers, and the typed timesheet of recent shifts.
struct SiteLogView: View {
    @StateObject private var viewModel: SiteLogViewModel
    let onGround: () -> Void

    init(viewModel: SiteLogViewModel, onGround: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onGround = onGround
    }

    var body: some View {
        HoistShell(floor: .log, onGround: onGround) {
            TiledBackground(texture: "tex_concrete", tint: Theme.Colors.asphalt.opacity(0.35))
        } content: {
            ScrollView {
                VStack(spacing: 18) { recordCard; stickerHat; timesheet }
                .padding(16)
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $viewModel.selectedSticker) { sticker in
            StickerDetail(achievement: sticker)
                .compactSheetHeight(300)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Log.screen)
    }

    // MARK: - Record card on the clipboard

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECORD CARD")
                .font(.typed(13, bold: true))
                .foregroundStyle(Theme.Colors.inkSoft)
            HStack(alignment: .firstTextBaseline) {
                Text("Best shift")
                    .font(.body(16, bold: true))
                    .foregroundStyle(Theme.Colors.ink)
                Spacer()
                Text("\(Formatters.integer(viewModel.bestScore)) pts")
                    .font(.display(28, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.ink)
                    .monospacedDigit()
                    .accessibilityIdentifier(AccessibilityID.Log.bestScore)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.stats) { stat in
                    HStack(spacing: 8) {
                        ArtImage(stat.art)
                            .frame(width: 30, height: 30)
                            .padding(4)
                            .background(Circle().fill(Theme.Colors.graphite.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(stat.value)
                                .font(.display(19, relativeTo: .headline))
                                .foregroundStyle(Theme.Colors.ink)
                                .monospacedDigit()
                            Text(stat.label)
                                .font(.body(12))
                                .foregroundStyle(Theme.Colors.inkSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Log.stats)
        }
        .padding(.horizontal, 16)
        .padding(.top, 34)
        .padding(.bottom, 16)
        .background { clipboard }
    }

    /// Brown hardboard with a steel clip, holding manila paper.
    private var clipboard: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(red: 0.55, green: 0.42, blue: 0.27))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.ink, lineWidth: 2))
            .overlay {
                ManilaBackground(cornerRadius: 4)
                    .padding(.horizontal, 6)
                    .padding(.top, 22)
                    .padding(.bottom, 6)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Theme.Colors.concreteLight, Theme.Colors.concrete], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.Colors.ink, lineWidth: 1.5))
                    .frame(width: 90, height: 26)
                    .offset(y: 4)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    // MARK: - Hard hat stickers

    private var stickerHat: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Hard hat stickers")
                    .font(.display(20, relativeTo: .headline))
                    .foregroundStyle(Theme.Colors.concreteLight)
                Spacer()
                Text("\(viewModel.unlockedCount)/\(AchievementCatalog.count)")
                    .font(.display(18))
                    .foregroundStyle(Theme.Colors.hiVis)
            }
            ZStack(alignment: .bottom) {
                ArtImage("hard_hat_big")
                    .frame(maxWidth: 420)
                    .opacity(0.95)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 6) {
                    ForEach(viewModel.achievements) { achievement in
                        Button { viewModel.selectedSticker = achievement } label: {
                            ArtImage(achievement.art)
                                .frame(width: 46, height: 46)
                                .rotationEffect(.degrees(Double((achievement.sticker * 37) % 20) - 10))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(achievement.title)
                        .accessibilityValue(achievement.isUnlocked ? "Earned" : "\(Int(achievement.progress * 100)) percent")
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
                .frame(maxWidth: 420)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Log.stickers)
            Text("Tap a sticker to see how to earn it.")
                .font(.body(13))
                .foregroundStyle(Theme.Colors.concreteLight.opacity(0.9))
        }
    }

    // MARK: - Timesheet

    private var timesheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TIMESHEET")
                .font(.typed(15, bold: true))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.bottom, 8)
            if viewModel.entries.isEmpty {
                VStack(spacing: 10) {
                    ArtImage("punch_card").frame(width: 110)
                    Text("No shifts logged yet. Clock in at the time clock and your shifts will be typed up here.")
                        .font(.typed(15))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Log.empty)
            } else {
                HStack {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Crew").frame(width: 34)
                    Text("Fl").frame(width: 34, alignment: .trailing)
                    Text("Points").frame(width: 70, alignment: .trailing)
                    Text("Bolts").frame(width: 54, alignment: .trailing)
                }
                .font(.typed(12, bold: true))
                .foregroundStyle(Theme.Colors.inkSoft)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.ink).frame(height: 1.5) }
                ForEach(viewModel.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.date)
                            Text("\(entry.time) · \(entry.duration)").font(.typed(11)).foregroundStyle(Theme.Colors.inkSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ArtImage(entry.foreman.portraitArt)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                            .frame(width: 34)
                        Text("\(entry.floors)").frame(width: 34, alignment: .trailing)
                        Text(entry.score).frame(width: 70, alignment: .trailing)
                        Text(entry.bolts).frame(width: 54, alignment: .trailing)
                    }
                    .font(.typed(14))
                    .foregroundStyle(Theme.Colors.ink)
                    .monospacedDigit()
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.steel.opacity(0.35)).frame(height: 1) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.date), \(entry.foreman.name), \(entry.floors) floors, \(entry.score) points, \(entry.bolts) bolts")
                }
            }
        }
        .padding(16)
        .background { ManilaBackground(cornerRadius: 4) }
    }
}

private struct StickerDetail: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 12) {
            ArtImage(achievement.art).frame(width: 90, height: 90)
            Text(achievement.title)
                .font(.display(26))
                .foregroundStyle(Theme.Colors.ink)
            Text(achievement.detail)
                .font(.body(16))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            if achievement.isUnlocked {
                Text("Earned").font(.body(15, bold: true)).foregroundStyle(Theme.Colors.safetyGreen)
            } else {
                ProgressView(value: achievement.progress)
                    .tint(Theme.Colors.hiVisDeep)
                    .frame(maxWidth: 220)
                Text("\(Int(achievement.progress * 100))% there").font(.typed(14)).foregroundStyle(Theme.Colors.inkSoft)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TiledBackground(texture: "tex_manila"))
    }
}

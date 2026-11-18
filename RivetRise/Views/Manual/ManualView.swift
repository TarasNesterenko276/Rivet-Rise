import SwiftUI

/// The site manual: a spiral-bound safety booklet, one illustrated page per mechanic.
struct ManualView: View {
    @StateObject private var viewModel: ManualViewModel
    let onGround: () -> Void

    init(viewModel: ManualViewModel, onGround: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onGround = onGround
    }

    var body: some View {
        HoistShell(floor: .manual, onGround: onGround) {
            TiledBackground(texture: "tex_concrete", tint: Color.black.opacity(0.2))
        } content: {
            VStack(spacing: 14) {
                TabView(selection: $viewModel.index) {
                    ForEach(viewModel.pages) { page in
                        ScrollView {
                            pageView(page)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                        }
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: Theme.Metrics.maxContentWidth)

                pageDots
                controls
                    .padding(.horizontal, 18)
                    .frame(maxWidth: Theme.Metrics.maxContentWidth)
            }
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.index)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Manual.screen)
    }

    private func pageView(_ page: ManualPage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Spiral binding.
            HStack(spacing: 14) {
                ForEach(0..<12, id: \.self) { _ in
                    Capsule()
                        .strokeBorder(Theme.Colors.graphite, lineWidth: 3)
                        .frame(width: 10, height: 22)
                }
            }
            .frame(maxWidth: .infinity)
            .offset(y: -22)
            .padding(.bottom, -22)
            .accessibilityHidden(true)

            ArtImage(page.art)
                .frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline) {
                Text("\(page.id + 1).")
                    .font(.display(26))
                    .foregroundStyle(Theme.Colors.hiVisDeep)
                Text(page.title)
                    .font(.display(26, relativeTo: .title))
                    .foregroundStyle(Theme.Colors.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(page.body)
                .font(.body(17))
                .foregroundStyle(Theme.Colors.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .padding(.top, 10)
        .background { ManilaBackground(cornerRadius: 6) }
        .padding(.top, 14)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.pages) { page in
                RoundedRectangle(cornerRadius: 2)
                    .fill(page.id == viewModel.index ? Theme.Colors.hiVis : Theme.Colors.concrete.opacity(0.5))
                    .frame(width: page.id == viewModel.index ? 22 : 10, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(viewModel.index + 1) of \(viewModel.pages.count)")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if viewModel.index > 0 {
                Button("Back") { viewModel.previous() }
                    .buttonStyle(FormButtonStyle())
            } else {
                Button("Skip") { viewModel.finish() }
                    .buttonStyle(FormButtonStyle())
            }
            Button(viewModel.isLastPage ? viewModel.doneTitle : "Next page") { viewModel.next() }
                .buttonStyle(HiVisButtonStyle(isProminent: false))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(viewModel.isLastPage ? AccessibilityID.Manual.done : AccessibilityID.Manual.next)
        }
    }
}

import SwiftUI

struct LoginScreen: View {
    let state: LoginState
    let onSocialLogin: (LoginProvider) -> Void
    let onReviewLogin: (String, String) -> Void
    let onDismissError: () -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var reviewPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    GText(text: LoginText.name, size: 30, weight: 800, color: GColor.loginInk)
                    GText(text: LoginText.tagline, color: GColor.loginInkSoft, trackingAdjustment: -0.30)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, G.dp(48))
                .padding(.bottom, G.small)

                LoginGarden()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(-1)

                panel
            }
            .background(GColor.loginSky)

            if let error = state.error {
                Button(action: onDismissError) {
                    GText(text: error, color: .white)
                        .padding(G.dp(16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GColor.text, in: RoundedRectangle(cornerRadius: G.dp(4)))
                }
                .buttonStyle(.plain)
                .padding(G.dp(12))
                .accessibilityLabel(error)
                .accessibilityHint("누르면 닫습니다")
            }
        }
        .overlay {
            if reviewPresented {
                ReviewLoginDialog(
                    onCancel: { reviewPresented = false },
                    onSubmit: { identifier, password in
                        reviewPresented = false
                        onReviewLogin(identifier, password)
                    }
                )
            }
        }
    }

    private var panel: some View {
        VStack(spacing: pixelAligned(G.small)) {
            GText(text: LoginText.headline, size: 18, weight: 700, color: GColor.loginInk, alignment: .center)
            if let recent = state.recentTitle {
                GText(text: recent, color: GColor.muted)
            }
            socialButton(.kakao)
            socialButton(.google)
            GText(text: LoginText.terms, size: 11, color: GColor.muted, alignment: .center, trackingAdjustment: -0.10)
            Button { reviewPresented = true } label: {
                GText(text: state.title(for: .review), size: 11, color: GColor.muted, underline: true)
                    .padding(.horizontal, G.gap)
                    .padding(.vertical, pixelAligned(G.small))
            }
            .buttonStyle(.plain)
            .disabled(state.isBusy)
        }
        .padding(.horizontal, G.gutter)
        .padding(.bottom, pixelAligned(G.gutter))
        .frame(maxWidth: .infinity)
        .background(GColor.loginPanel)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pixelAligned(_ points: CGFloat) -> CGFloat {
        (points * displayScale).rounded() / displayScale
    }

    private func socialButton(_ provider: LoginProvider) -> some View {
        let isKakao = provider == .kakao
        let background = state.isBusy ? GColor.disabled : (isKakao ? GColor.kakao : .white)
        let foreground = state.isBusy ? Color.white : (isKakao ? GColor.kakaoInk : GColor.text)
        return Button { onSocialLogin(provider) } label: {
            HStack(spacing: G.dp(8)) {
                Group {
                    if isKakao {
                        KakaoSymbol().fill(Color(hex: 0x191919))
                    } else {
                        ArtImage(asset: .google).scaledToFit()
                    }
                }
                .frame(width: G.dp(18), height: G.dp(18))
                .accessibilityHidden(true)
                GText(text: state.title(for: provider), size: 15, weight: 700, color: foreground)
                    .lineLimit(1)
            }
            .padding(.horizontal, G.dp(24))
        }
        .buttonStyle(GButtonStyle(background: background, outline: !isKakao))
        .disabled(state.isBusy)
        .accessibilityLabel(state.title(for: provider))
    }
}

private struct LoginGarden: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ArtImage(asset: .gardenBack)
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
                    .clipped()
                    .accessibilityHidden(true)
                ArtImage(asset: .wave)
                    .scaledToFit()
                    .frame(width: G.dp(220), height: min(G.dp(220), max(0, geometry.size.height - G.dp(36))))
                    .padding(.bottom, G.dp(36))
                    .accessibilityLabel("손 흔드는 꾸기")
                ArtImage(asset: .gardenFront)
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: G.dp(64))
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(colors: [.clear, GColor.loginPanel], startPoint: .top, endPoint: .bottom)
                    .frame(height: G.dp(72))
                    .accessibilityHidden(true)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .clipped()
        }
    }
}

private struct ReviewLoginDialog: View {
    let onCancel: () -> Void
    let onSubmit: (String, String) -> Void
    private enum Field: Hashable { case identifier, password }
    @FocusState private var focusedField: Field?
    @State private var identifier = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: G.dp(16)) {
                GText(text: LoginText.reviewTitle, size: 18, weight: 700)
                GText(text: LoginText.reviewDescription)
                TextField("아이디", text: $identifier)
                    .focused($focusedField, equals: .identifier)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                SecureField("비밀번호", text: $password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("취소", action: onCancel)
                    Button("로그인") { onSubmit(identifier, password) }
                        .disabled(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
            }
            .padding(G.dp(24))
            .background(.white, in: RoundedRectangle(cornerRadius: G.dp(28)))
            .padding(G.dp(24))
        }
        .accessibilityAddTraits(.isModal)
    }
}

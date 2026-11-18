import FirebaseCore
import FirebaseInstallations
import FirebaseMessaging
import SwiftUI
import UserNotifications

@MainActor
final class PushRegistration: NSObject, ObservableObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    static weak var current: PushRegistration?
    @Published private(set) var message = ""
    @Published private(set) var openedInbox: UUID?
    private var session: AuthSession?
    private var pending: Task<Void, Never>?
    private var enabledForSession = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Self.current = self
        UNUserNotificationCenter.current().delegate = self
        func setting(_ name: String) -> String? {
            guard let value = Bundle.main.object(forInfoDictionaryKey: name) as? String,
                  !value.isEmpty, !value.hasPrefix("$(") else { return nil }
            return value
        }
        if let id = setting("KkugiFirebaseAppID"), let sender = setting("KkugiFirebaseSenderID"),
           let project = setting("KkugiFirebaseProjectID"), let key = setting("KkugiFirebaseAPIKey") {
            let config = FirebaseOptions(googleAppID: id, gcmSenderID: sender)
            config.projectID = project
            config.apiKey = key
            FirebaseApp.configure(options: config)
            Messaging.messaging().delegate = self
        }
        return true
    }

    func attach(_ session: AuthSession?) async {
        self.session = session
        enabledForSession = (try? await session?.current())?.onboarded == true
        guard enabledForSession, FirebaseApp.app() != nil else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func authorize() async {
        guard FirebaseApp.app() != nil else { message = "이 빌드에 알림 서비스 설정이 없어요"; return }
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if allowed { UIApplication.shared.registerForRemoteNotifications(); message = "알림 등록 중" }
            else { message = "iPhone 설정에서 꾸기의 알림을 허용해 주세요" }
        } catch { message = "알림 권한을 확인하지 못했어요" }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
        register()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        message = "이 기기의 원격 알림을 등록하지 못했어요"
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in self.register() }
    }

    private func register() {
        guard enabledForSession, let session, FirebaseApp.app() != nil, Messaging.messaging().apnsToken != nil else { return }
        let previous = pending
        pending = Task {
            await previous?.value
            guard !Task.isCancelled, enabledForSession else { return }
            do {
                guard let member = try await session.current(), member.onboarded else { return }
                let token = try await Messaging.messaging().token()
                let install = try await Installations.installations().installationID()
                guard enabledForSession, !Task.isCancelled else { return }
                UserDefaults.standard.set(install, forKey: "kkugi.push.install")
                _ = try await session.protectedRequest("api/v1/members/me/devices/" + install, method: "PUT",
                    body: JSONEncoder().encode(MemberDeviceRequest(fcmToken: token)), memberID: member.memberID)
                message = "알림을 받을 수 있어요"
            } catch { message = "알림을 등록하지 못했어요. 다시 시도해 주세요" }
        }
    }

    func detachBeforeLogout() async throws {
        enabledForSession = false
        await pending?.value
        pending = nil
        guard let session, FirebaseApp.app() != nil, let member = try await session.current(), member.onboarded else { return }
        guard let install = UserDefaults.standard.string(forKey: "kkugi.push.install") else { return }
        _ = try await session.protectedRequest("api/v1/members/me/devices/" + install, method: "DELETE", memberID: member.memberID)
        UserDefaults.standard.removeObject(forKey: "kkugi.push.install")
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func consumeInbox() { openedInbox = nil }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in self.openedInbox = UUID(); completionHandler() }
    }
}

struct NotificationSettingsRow: View {
    @ObservedObject var registration: PushRegistration
    var body: some View {
        Button("알림 켜기") { Task { await registration.authorize() } }
        if !registration.message.isEmpty { Text(registration.message) }
        Link("iPhone 알림 설정", destination: URL(string: UIApplication.openNotificationSettingsURLString)!)
    }
}

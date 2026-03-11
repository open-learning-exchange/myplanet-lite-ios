//
//  ContentView.swift
//  myPlanet Lite
//
//  Author: Walfre López Prado
//  * Email: loppra@plataformasinformaticas.com
//  * Creation date: 04/01/2026
//

import SwiftUI
import UIKit
import PhotosUI

private func appLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

struct ContentView: View {
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = -20
    @State private var textOffset: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var versionOffset: CGFloat = 0
    @State private var versionOpacity: Double = 0
    @State private var isServerConnected = false
    @State private var showLogin = false
    @State private var showLanguagePicker = false
    @State private var showAddServer = false
    @State private var isLoggedIn = false
    @AppStorage("app_language") private var appLanguage = "en"
    @AppStorage("server_host") private var selectedServerHost = ServerOption.guatemala.host
    @AppStorage("custom_servers") private var customServersData = "[]"
    @AppStorage("planet_parent_code") private var planetParentCode = ""
    @AppStorage("planet_code") private var planetCode = ""
    @AppStorage("planet_keys") private var planetKeysData = ""
    @AppStorage("auth_session") private var authSessionCookie = ""
    @AppStorage("avatar_user") private var avatarUser = ""
    @AppStorage("avatar_digest") private var avatarDigest = ""
    @AppStorage("avatar_image_base64") private var avatarImageBase64 = ""
    @AppStorage("profile_display_name") private var profileDisplayName = ""
    @AppStorage("profile_username") private var profileUsername = ""
    @AppStorage("selected_team_id") private var selectedTeamId = ""
    @AppStorage("selected_team_name") private var selectedTeamName = ""
    @AppStorage("remember_me_enabled") private var rememberMeEnabled = false
    @AppStorage("remembered_username") private var rememberedUsername = ""
    @AppStorage("remembered_password") private var rememberedPassword = ""
    @AppStorage("ai_consent_accepted") private var aiConsentAccepted = false
    @State private var isAutoLoggingIn = false

    var body: some View {
        Group {
            if showLogin {
                if isLoggedIn {
                    DashboardView(
                        avatarImageData: Data(base64Encoded: avatarImageBase64),
                        displayName: profileDisplayName,
                        username: profileUsername,
                        serverHost: selectedServerHost,
                        planetCode: planetCode,
                        parentCode: planetParentCode,
                        authSessionCookie: authSessionCookie,
                        onLogout: {
                            logout()
                        }
                    )
                } else {
                    LoginView(
                        selectedServerHost: $selectedServerHost,
                        customServers: customServers,
                        isServerConnected: isServerConnected,
                        onLanguageTap: {
                            showLanguagePicker = true
                        },
                        onAddServerTap: {
                            showAddServer = true
                        },
                        onClearServersTap: {
                            clearCustomServers()
                        },
                        onLogin: { username, password, completion in
                            Task {
                                let success = await login(
                                    host: selectedServerHost,
                                    username: username,
                                    password: password
                                )
                                completion(success)
                            }
                        },
                        onLoginSuccess: { username in
                            isLoggedIn = true
                            Task {
                                await loadAvatarIfNeeded(host: selectedServerHost, username: username)
                            }
                        },
                        appLanguage: appLanguage
                    )
                }
            } else {
                splashView
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showLogin)
        .environment(\.locale, Locale(identifier: appLanguage))
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(selectedLanguage: $appLanguage)
                .environment(\.locale, Locale(identifier: appLanguage))
        }
        .sheet(isPresented: $showAddServer) {
            AddServerView { newServer in
                addCustomServer(newServer)
                selectedServerHost = newServer.host
            }
            .environment(\.locale, Locale(identifier: appLanguage))
        }
        .task(id: showLogin) {
            guard showLogin else { return }
            ensureSelectedServerHost()
            isServerConnected = false
            await updateConnectionStatus(for: selectedServerHost)
            await attemptAutoLogin()
        }
        .onChange(of: selectedServerHost) { _, newValue in
            isServerConnected = false
            Task {
                await updateConnectionStatus(for: newValue)
            }
        }
    }

    private var splashView: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotation))
                        .offset(y: yOffset)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 6)

                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(AppStrings.appName)
                                .foregroundColor(Color("darkOle"))
                            Text(AppStrings.appVariant)
                                .foregroundColor(Color("greenOleLogo"))
                        }
                        .font(.system(size: 28, weight: .semibold))

                        Text(AppStrings.appVersion)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color("darkOle").opacity(0.8))
                            .offset(y: versionOffset)
                            .opacity(versionOpacity)
                    }
                    .offset(x: textOffset)
                    .opacity(textOpacity)
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height / 3)

                VStack {
                    Spacer()

                    Link(destination: URL(string: AppStrings.companyUrl)!) {
                        HStack(spacing: 4) {
                            Text(AppStrings.poweredBy)
                                .foregroundColor(.black)
                            Text(AppStrings.companyName)
                                .foregroundColor(.green)
                        }
                        .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                yOffset = -proxy.size.height / 2
                rotation = -20
                textOffset = proxy.size.width / 2
                textOpacity = 0
                versionOffset = proxy.size.height / 6
                versionOpacity = 0

                withAnimation(.interpolatingSpring(stiffness: 160, damping: 12)) {
                    yOffset = 0
                    rotation = 0
                }

                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    textOffset = 0
                    textOpacity = 1
                }

                withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
                    versionOffset = 0
                    versionOpacity = 1
                }

                let animationDuration = AppTiming.animationTotal
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 1.5) {
                    showLogin = true
                }
            }
        }
    }

    private var customServers: [CustomServer] {
        guard let data = customServersData.data(using: .utf8),
              let servers = try? JSONDecoder().decode([CustomServer].self, from: data) else {
            return []
        }
        return servers
    }

    private func addCustomServer(_ server: CustomServer) {
        var updated = customServers
        updated.append(server)
        if let data = try? JSONEncoder().encode(updated) {
            customServersData = String(decoding: data, as: UTF8.self)
        }
    }

    private func ensureSelectedServerHost() {
        guard selectedServerHost.isEmpty else { return }
        selectedServerHost = ServerOption.defaultServers.first?.host ?? ServerOption.guatemala.host
    }

    private func updateConnectionStatus(for host: String) async {
        isServerConnected = await isServerReachable(host: host)
    }

    private func isServerReachable(host: String) async -> Bool {
        let baseHost = host.hasSuffix("/") ? host : "\(host)/"
        guard let url = URL(string: "\(baseHost)db/configurations/_all_docs?include_docs=true") else {
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    return false
                }
                storeConfiguration(from: data)
                return true
            }
            return false
        } catch {
            return false
        }
    }

    private func storeConfiguration(from data: Data) {
        guard let configuration = try? JSONDecoder().decode(ServerConfigurationResponse.self, from: data),
              let doc = configuration.rows.first?.doc else {
            return
        }

        if let parentCode = doc.parentCode {
            planetParentCode = parentCode
        }
        if let code = doc.code {
            planetCode = code
        }
        if let keys = doc.keys,
           let encoded = try? JSONEncoder().encode(keys) {
            planetKeysData = String(decoding: encoded, as: UTF8.self)
        }
    }

    private func loadAvatarIfNeeded(host: String, username: String) async {
        guard let profile = await fetchUserProfile(host: host, username: username) else {
            return
        }

        let digest = profile.attachments?.img?.digest ?? ""
        let fullName = [profile.firstName, profile.middleName, profile.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        _ = await MainActor.run {
            profileUsername = profile.name ?? username
            profileDisplayName = fullName.isEmpty ? username : fullName
        }
        if digest.isEmpty {
            _ = await MainActor.run {
                avatarUser = username
                avatarDigest = ""
                avatarImageBase64 = ""
            }
            return
        }

        let shouldRefresh = avatarUser != username || avatarDigest != digest || avatarImageBase64.isEmpty
        guard shouldRefresh else { return }

        if let imageData = await fetchAvatarImage(host: host, username: username) {
            let base64 = imageData.base64EncodedString()
            _ = await MainActor.run {
                avatarUser = username
                avatarDigest = digest
                avatarImageBase64 = base64
            }
        }
    }

    private func fetchUserProfile(host: String, username: String) async -> UserProfile? {
        let baseHost = host.hasSuffix("/") ? host : "\(host)/"
        guard let url = URL(string: "\(baseHost)db/_users/org.couchdb.user:\(username)") else {
            return nil
        }

        do {
            let request = requestWithAuthCookie(for: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            return nil
        }
    }

    private func fetchAvatarImage(host: String, username: String) async -> Data? {
        let baseHost = host.hasSuffix("/") ? host : "\(host)/"
        guard let url = URL(string: "\(baseHost)db/_users/org.couchdb.user:\(username)/img") else {
            return nil
        }

        do {
            let request = requestWithAuthCookie(for: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func requestWithAuthCookie(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private func clearCustomServers() {
        let customHosts = Set(customServers.map(\.host))
        if customHosts.contains(selectedServerHost) {
            selectedServerHost = ServerOption.guatemala.host
        }
        customServersData = "[]"
    }

    private func attemptAutoLogin() async {
        guard !isAutoLoggingIn,
              !isLoggedIn,
              rememberMeEnabled,
              aiConsentAccepted,
              !rememberedUsername.isEmpty,
              !rememberedPassword.isEmpty else { return }
        isAutoLoggingIn = true
        let success = await login(
            host: selectedServerHost,
            username: rememberedUsername,
            password: rememberedPassword
        )
        isAutoLoggingIn = false
        if success {
            isLoggedIn = true
            await loadAvatarIfNeeded(host: selectedServerHost, username: rememberedUsername)
        }
    }

    private func logout() {
        authSessionCookie = ""
        isLoggedIn = false
        aiConsentAccepted = false
        rememberMeEnabled = false
        rememberedUsername = ""
        rememberedPassword = ""
        avatarUser = ""
        avatarDigest = ""
        avatarImageBase64 = ""
        profileDisplayName = ""
        profileUsername = ""
    }

    private func login(host: String, username: String, password: String) async -> Bool {
        let baseHost = host.hasSuffix("/") ? host : "\(host)/"
        guard let url = URL(string: "\(baseHost)db/_session") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = LoginRequest(name: username, password: password)
        guard let bodyData = try? JSONEncoder().encode(body) else { return false }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return false
            }

            if let loginResponse = try? JSONDecoder().decode(LoginResponse.self, from: data),
               loginResponse.ok {
                storeAuthCookie(from: httpResponse, url: url)
                await sendLoginActivity(host: host, username: username)
                await validateFavoriteTeamMembership(host: host, username: username, password: password)
                return true
            }
            return false
        } catch {
            return false
        }
    }

    private func validateFavoriteTeamMembership(host: String, username: String, password: String) async {
        guard !selectedTeamId.isEmpty else { return }

        let payload = TeamsMembershipsQuery(
            selector: TeamsMembershipsQuery.Selector(
                userId: "org.couchdb.user:\(username)",
                teamType: "local",
                docType: "membership",
                status: TeamsMembershipsQuery.Selector.Status(
                    or: [
                        ["$exists": .bool(false)],
                        ["$ne": .string("archived")]
                    ]
                )
            )
        )

        let response: TeamsMembershipsResponse? = await performTeamValidationRequest(host: host, username: username, password: password, body: payload)
        let memberships = response?.docs ?? []

        let isMember = memberships.contains { $0.teamId == selectedTeamId }

        if !isMember {
            _ = await MainActor.run {
                selectedTeamId = ""
                selectedTeamName = ""
            }
        }
    }

    private func performTeamValidationRequest<T: Encodable, U: Decodable>(host: String, username: String, password: String, body: T) async -> U? {
        let baseHost = host.hasSuffix("/") ? host : "\(host)/"
        guard let url = URL(string: "\(baseHost)db/teams/_find") else { return nil }
        guard let bodyData = try? JSONEncoder().encode(body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        let credentials = "\(username):\(password)"
        if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(U.self, from: data)
        } catch {
            return nil
        }
    }

    private func storeAuthCookie(from response: HTTPURLResponse, url: URL) {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            if let key = item.key as? String, let value = item.value as? String {
                result[key] = value
            }
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        if let authCookie = cookies.first(where: { $0.name == "AuthSession" }) {
            authSessionCookie = authCookie.value
        }
    }

    private func sendLoginActivity(host: String, username: String) async {
        let baseHost = host.hasSuffix("/") ? host : "\(host)/"
        guard let url = URL(string: "\(baseHost)db/login_activities") else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let oneHourLater = now + (60 * 60 * 1000)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        let payload = LoginActivityPayload(
            user: username,
            type: "login",
            loginTime: now,
            logoutTime: oneHourLater,
            createdOn: planetCode,
            parentCode: planetParentCode,
            androidId: deviceId,
            deviceName: UIDevice.current.model,
            customDeviceName: UIDevice.current.name
        )

        guard let body = try? JSONEncoder().encode(payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = body

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
        }
    }
}

struct LoginRequest: Encodable {
    let name: String
    let password: String
}

struct LoginResponse: Decodable {
    let ok: Bool
    let name: String?
    let roles: [String]?
}

struct LoginActivityPayload: Encodable {
    let user: String
    let type: String
    let loginTime: Int64
    let logoutTime: Int64
    let createdOn: String
    let parentCode: String
    let androidId: String
    let deviceName: String
    let customDeviceName: String
}

struct ServerConfigurationResponse: Decodable {
    let rows: [Row]

    struct Row: Decodable {
        let doc: Doc?
    }

    struct Doc: Decodable {
        let parentCode: String?
        let code: String?
        let keys: Keys?
    }

    struct Keys: Codable {
        let openai: String?
        let perplexity: String?
        let deepseek: String?
        let gemini: String?
    }
}

struct UserProfile: Decodable {
    let attachments: Attachments?
    let name: String?
    let firstName: String?
    let middleName: String?
    let lastName: String?

    struct Attachments: Decodable {
        let img: Attachment?
    }

    struct Attachment: Decodable {
        let digest: String?
    }

    private enum CodingKeys: String, CodingKey {
        case attachments = "_attachments"
        case name
        case firstName
        case middleName
        case lastName
    }
}

struct LoginView: View {
    @Binding var selectedServerHost: String
    let customServers: [CustomServer]
    let isServerConnected: Bool
    let onLanguageTap: () -> Void
    let onAddServerTap: () -> Void
    let onClearServersTap: () -> Void
    let onLogin: (String, String, @escaping (Bool) -> Void) -> Void
    let onLoginSuccess: (String) -> Void
    let appLanguage: String
    @AppStorage("remember_me_enabled") private var rememberMeEnabled = false
    @AppStorage("remembered_username") private var rememberedUsername = ""
    @AppStorage("remembered_password") private var rememberedPassword = ""
    @AppStorage("ai_consent_accepted") private var aiConsentAccepted = false
    @State private var username = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var rememberMe = false
    @State private var showConnectionErrorAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showAiTranslationNotice = false
    @State private var showRegisterWizard = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white
                .ignoresSafeArea()

            Button(action: onLanguageTap) {
                Image("IconLang")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .padding(.top, 16)
                    .padding(.trailing, 25)
            }

            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                HStack(spacing: 8) {
                    Text(AppStrings.appName)
                        .foregroundColor(Color("darkOle"))
                    Text(AppStrings.appVariant)
                        .foregroundColor(Color("greenOleLogo"))
                }
                .font(.system(size: 28, weight: .semibold))

                HStack(spacing: 6) {
                    Text("version_label")
                    Text(AppStrings.appVersion)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

                HStack(spacing: 8) {
                    ServerSelectorView(
                        selectedServerHost: $selectedServerHost,
                        customServers: customServers,
                        onAddServerTap: onAddServerTap,
                        onClearServersTap: onClearServersTap
                    )

                    Image(isServerConnected ? "IconConnected" : "IconDisconnected")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 12) {
                    TextField("username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    ZStack(alignment: .trailing) {
                        Group {
                            if isPasswordVisible {
                                TextField("password", text: $password)
                            } else {
                                SecureField("password", text: $password)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding(.trailing, 36)

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 8)
                        .accessibilityLabel(isPasswordVisible ? "Hide Password" : "Show Password")
                    }

                    Button {
                        rememberMe.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: rememberMe ? "checkmark.square" : "square")
                                .foregroundColor(.gray)
                            Text("remember_me")
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Button("login") {
                        if aiConsentAccepted {
                            performLogin()
                        } else {
                            showAiTranslationNotice = true
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("button_primary"))
                        .foregroundColor(.white)
                        .disabled(!isServerConnected)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 8) {
                        Text("no_account")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("app_black"))

                        Button("register") {
                            showRegisterWizard = true
                        }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("button_primary"))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 16)

                    Button("privacy_notice") {
                        showPrivacyPolicy = true
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color("app_black"))

                    Link(destination: URL(string: "http://plataformasinformaticas.com")!) {
                        HStack(spacing: 4) {
                            Text("Powered by")
                                .foregroundColor(Color("app_black"))
                            Text("Plataformas Informáticas")
                                .foregroundColor(Color("greenOleLogo"))
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 64)
        }
        .alert("connection_invalid", isPresented: $showConnectionErrorAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("ai_translation_title", isPresented: $showAiTranslationNotice) {
            Button("accept") {
                aiConsentAccepted = true
                performLogin()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("ai_translation_message")
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
                .environment(\.locale, Locale(identifier: appLanguage))
        }
        .sheet(isPresented: $showRegisterWizard) {
            RegisterWizardView(baseUrl: selectedServerHost)
                .environment(\.locale, Locale(identifier: appLanguage))
        }
        .onAppear {
            rememberMe = rememberMeEnabled
            if rememberMeEnabled {
                username = rememberedUsername
                password = rememberedPassword
            }
        }
    }

    private func performLogin() {
        onLogin(username, password) { success in
            if success {
                if rememberMe {
                    rememberMeEnabled = true
                    rememberedUsername = username
                    rememberedPassword = password
                } else {
                    rememberMeEnabled = false
                    rememberedUsername = ""
                    rememberedPassword = ""
                }
                onLoginSuccess(username)
            } else {
                showConnectionErrorAlert = true
            }
        }
    }
}

struct RegisterWizardView: View {
    @Environment(\.dismiss) private var dismiss
    let baseUrl: String
    @State private var step = 1
    @State private var username = ""
    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var selectedGender = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedLanguage = ""
    @State private var selectedLevel = ""
    @State private var useLoginAutofill = false
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isCheckingUsername = false
    @State private var showUsernameTakenInline = false
    @State private var showRegistrationError = false
    @AppStorage("remember_me_enabled") private var rememberMeEnabled = false
    @AppStorage("remembered_username") private var rememberedUsername = ""
    @AppStorage("remembered_password") private var rememberedPassword = ""
    @AppStorage("planet_code") private var planetCode = ""
    @AppStorage("planet_parent_code") private var planetParentCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(.top, 12)

                Text("register_intro")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("darkOle"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if step == 1 {
                    usernameStep
                } else if step == 2 {
                    nameStep
                } else if step == 3 {
                    birthDateStep
                } else if step == 4 {
                    genderStep
                } else if step == 5 {
                    contactStep
                } else if step == 6 {
                    passwordStep
                } else if step == 7 {
                    languageLevelStep
                } else {
                    licenseStep
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, 8)
            .safeAreaInset(edge: .bottom) {
                if step == 8 {
                    HStack(spacing: 12) {
                        Button("back") {
                            step = 7
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(Color("button_primary"))

                        Button("accept") {
                            Task {
                                await registerUser()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("button_primary"))
                        .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .background(.clear)
                } else {
                    Button("register_next") {
                        handleNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("button_primary"))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .background(.clear)
                    .disabled(isNextDisabled)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("back")
                        }
                    }
                }
            }
        }
        .alert("connection_invalid", isPresented: $showRegistrationError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("register_choose_username")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_username_rules")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            TextField("username", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: username) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let withoutSpaces = trimmed.replacingOccurrences(of: " ", with: "")
                    if withoutSpaces != newValue {
                        username = withoutSpaces
                    }
                    showUsernameTakenInline = false
                }

            if showUsernameTakenInline {
                Text("user_taken_message")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("register_name_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_name_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            VStack(spacing: 10) {
                TextField("first_name", text: $firstName)
                    .textFieldStyle(.roundedBorder)

                TextField("middle_name", text: $middleName)
                    .textFieldStyle(.roundedBorder)

                TextField("last_name", text: $lastName)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var birthDateStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("register_birth_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_birth_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            DatePicker(
                "date_of_birth",
                selection: $birthDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .onChange(of: birthDate) { _, _ in
                hasBirthDate = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var genderStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("register_gender_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_gender_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            VStack(spacing: 12) {
                genderOption(title: "gender_female", value: "female")
                genderOption(title: "gender_male", value: "male")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func genderOption(title: String, value: String) -> some View {
        Button {
            selectedGender = value
        } label: {
            HStack {
                Text(LocalizedStringKey(title))
                    .foregroundColor(Color("darkOle"))
                Spacer()
                Image(systemName: selectedGender == value ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedGender == value ? Color("button_primary") : .gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedGender == value ? Color("button_primary") : Color.gray.opacity(0.4),
                        lineWidth: 1
                    )
            )
        }
    }

    private var contactStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("register_contact_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_contact_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            VStack(spacing: 10) {
                TextField("email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .onChange(of: email) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        let withoutSpaces = trimmed.replacingOccurrences(of: " ", with: "")
                        if withoutSpaces != newValue {
                            email = withoutSpaces
                        }
                    }

                TextField("phone_number", text: $phoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .onChange(of: phoneNumber) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != newValue {
                            phoneNumber = digits
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("register_password_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_password_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            VStack(spacing: 10) {
                passwordField(
                    title: LocalizedStringKey("password"),
                    text: $password,
                    isVisible: $isPasswordVisible
                )

                passwordField(
                    title: LocalizedStringKey("confirm_password"),
                    text: $confirmPassword,
                    isVisible: $isConfirmPasswordVisible
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func passwordField(
        title: LocalizedStringKey,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        ZStack(alignment: .trailing) {
            Group {
                if isVisible.wrappedValue {
                    TextField(title, text: text)
                } else {
                    SecureField(title, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.trailing, 36)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 8)
            .accessibilityLabel(isVisible.wrappedValue ? "Hide Password" : "Show Password")
        }
    }

    private var languageLevelStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("register_language_level_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_language_level_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("language_label")
                    .font(.subheadline)
                    .foregroundColor(Color("darkOle"))

                Picker("language_label", selection: $selectedLanguage) {
                    Text("select_option").tag("")
                    ForEach(availableLanguages, id: \.value) { option in
                        Text(option.displayName).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { _, _ in
                    selectedLevel = ""
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("level_label")
                    .font(.subheadline)
                    .foregroundColor(Color("darkOle"))

                Picker("level_label", selection: $selectedLevel) {
                    Text("select_option").tag("")
                    ForEach(availableLevels, id: \.value) { option in
                        Text(option.displayName).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var licenseStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("register_license_prompt")
                .font(.headline)
                .foregroundColor(Color("darkOle"))

            Text("register_license_helper")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("darkOle").opacity(0.8))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("eula_title")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color("darkOle"))

                    Text("eula_subtitle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("darkOle").opacity(0.85))

                    eulaSection(title: "eula_section1_title", body: "eula_section1_body")
                    eulaSection(title: "eula_section2_title", body: "eula_section2_body")
                    eulaSection(title: "eula_section3_title", body: "eula_section3_body")
                    eulaSection(title: "eula_section4_title", body: "eula_section4_body")
                    eulaSection(title: "eula_section5_title", body: "eula_section5_body")
                    eulaSection(title: "eula_section6_title", body: "eula_section6_body")
                    eulaSection(title: "eula_section7_title", body: "eula_section7_body")
                    eulaSection(title: "eula_section8_title", body: "eula_section8_body")
                }
                .padding(16)
            }
            .background(Color("app_black").opacity(0.03))
            .cornerRadius(12)

            Button {
                useLoginAutofill.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: useLoginAutofill ? "checkmark.square" : "square")
                        .foregroundColor(.gray)
                    Text("license_autofill")
                        .foregroundColor(Color("darkOle"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func eulaSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color("darkOle"))
            Text(LocalizedStringKey(body))
                .font(.footnote)
                .foregroundColor(Color("darkOle").opacity(0.85))
        }
    }

    private var availableLanguages: [(displayName: String, value: String)] {
        [
            ("Español", "Spanish"),
            ("English", "English"),
            ("Français", "French"),
            ("हिन्दी", "Hindi"),
            ("नेपाली", "Nepali"),
            ("Português", "Portuguese"),
            ("العربية", "Arabic"),
            ("Soomaali", "Somali")
        ]
    }

    private var availableLevels: [(displayName: String, value: String)] {
        levelOptionsByLanguage[selectedLanguage, default: levelOptionsByLanguage["English", default: []]]
    }

    private var levelOptionsByLanguage: [String: [(displayName: String, value: String)]] {
        [
            "Spanish": [
                ("Principiante", "Beginner"),
                ("Intermedio", "Intermediate"),
                ("Avanzado", "Advanced"),
                ("Experto", "Expert")
            ],
            "English": [
                ("Beginner", "Beginner"),
                ("Intermediate", "Intermediate"),
                ("Advanced", "Advanced"),
                ("Expert", "Expert")
            ],
            "French": [
                ("Débutant", "Beginner"),
                ("Intermédiaire", "Intermediate"),
                ("Avancé", "Advanced"),
                ("Expert", "Expert")
            ],
            "Hindi": [
                ("शुरुआती", "Beginner"),
                ("मध्यम", "Intermediate"),
                ("उन्नत", "Advanced"),
                ("विशेषज्ञ", "Expert")
            ],
            "Nepali": [
                ("सुरुआती", "Beginner"),
                ("मध्यम", "Intermediate"),
                ("उन्नत", "Advanced"),
                ("विशेषज्ञ", "Expert")
            ],
            "Portuguese": [
                ("Iniciante", "Beginner"),
                ("Intermediário", "Intermediate"),
                ("Avançado", "Advanced"),
                ("Especialista", "Expert")
            ],
            "Arabic": [
                ("مبتدئ", "Beginner"),
                ("متوسط", "Intermediate"),
                ("متقدم", "Advanced"),
                ("خبير", "Expert")
            ],
            "Somali": [
                ("Bilow", "Beginner"),
                ("Dhexe", "Intermediate"),
                ("Sare", "Advanced"),
                ("Khabiir", "Expert")
            ]
        ]
    }

    private var isNextDisabled: Bool {
        if step == 1 {
            return !isValidUsername || isCheckingUsername
        }
        if step == 2 {
            return firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if step == 3 {
            return !hasBirthDate
        }
        if step == 4 {
            return selectedGender.isEmpty
        }
        if step == 5 {
            return !isValidEmail || phoneNumber.isEmpty
        }
        if step == 6 {
            return !isValidPassword || password != confirmPassword
        }
        return selectedLanguage.isEmpty || selectedLevel.isEmpty
    }

    private func handleNext() {
        if step == 1 {
            Task {
                await validateUsername()
            }
        } else if step == 2 {
            step = 3
        } else if step == 3 {
            step = 4
        } else if step == 4 {
            step = 5
        } else if step == 5 {
            step = 6
        } else if step == 6 {
            step = 7
        } else if step == 7 {
            step = 8
        } else {
            // Placeholder for next step submission.
        }
    }

    private func validateUsername() async {
        let trimmedUsername = normalizedUsername
        guard isValidUsername else { return }
        guard let url = URL(string: "\(baseUrl)db/_users/org.couchdb.user:\(trimmedUsername)") else { return }
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    step = 2
                } else {
                    showUsernameTakenInline = true
                }
            }
        } catch {
        }
    }

    private var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    private var isValidUsername: Bool {
        let candidate = normalizedUsername
        guard !candidate.isEmpty else { return false }
        let pattern = "^[A-Za-z][A-Za-z0-9]*$"
        return candidate.range(of: pattern, options: .regularExpression) != nil
    }

    private var isValidEmail: Bool {
        let candidate = email.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard !candidate.isEmpty else { return false }
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return candidate.range(of: pattern, options: .regularExpression) != nil
    }

    private var isValidPassword: Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return false }
        let pattern = "^[A-Za-z0-9]+$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: birthDate)
    }

    private var selectedLanguageDisplayName: String {
        availableLanguages.first(where: { $0.value == selectedLanguage })?.displayName ?? selectedLanguage
    }

    private func registerUser() async {
        let trimmedUsername = normalizedUsername
        guard isValidUsername,
              !selectedGender.isEmpty,
              !selectedLevel.isEmpty,
              isValidEmail,
              !phoneNumber.isEmpty,
              isValidPassword,
              password == confirmPassword,
              let url = URL(string: "\(baseUrl)db/_users/org.couchdb.user:\(trimmedUsername)") else {
            showRegistrationError = true
            return
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let androidId = String(deviceId.replacingOccurrences(of: "-", with: "").prefix(16))

        let payload = RegistrationPayload(
            name: trimmedUsername,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            middleName: middleName.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            isUserAdmin: false,
            joinDate: Int64(Date().timeIntervalSince1970 * 1000),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: ""),
            planetCode: planetCode,
            parentCode: planetParentCode,
            language: selectedLanguage,
            level: selectedLevel,
            phoneNumber: phoneNumber,
            birthDate: formattedBirthDate,
            gender: selectedGender,
            type: "user",
            betaEnabled: false,
            androidId: androidId,
            uniqueAndroidId: deviceId,
            customDeviceName: UIDevice.current.name,
            roles: ["learner"]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                if useLoginAutofill {
                    rememberMeEnabled = true
                    rememberedUsername = trimmedUsername
                    rememberedPassword = password
                }
                dismiss()
            } else {
                showRegistrationError = true
            }
        } catch {
            showRegistrationError = true
        }
    }
}

private struct RegistrationPayload: Codable {
    let name: String
    let firstName: String
    let lastName: String
    let middleName: String
    let password: String
    let isUserAdmin: Bool
    let joinDate: Int64
    let email: String
    let planetCode: String
    let parentCode: String
    let language: String
    let level: String
    let phoneNumber: String
    let birthDate: String
    let gender: String
    let type: String
    let betaEnabled: Bool
    let androidId: String
    let uniqueAndroidId: String
    let customDeviceName: String
    let roles: [String]
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedStringKey("privacy_title"))
                        .font(.title2)
                        .fontWeight(.bold)

                    policySection(title: "privacy_intro_title", body: "privacy_intro_body")
                    policySection(title: "privacy_collect_title", body: "privacy_collect_body")
                    policySection(title: "privacy_use_title", body: "privacy_use_body")
                    policySection(title: "privacy_storage_title", body: "privacy_storage_body")
                    policySection(title: "privacy_share_title", body: "privacy_share_body")
                    policySection(title: "privacy_rights_title", body: "privacy_rights_body")
                    policySection(title: "privacy_security_title", body: "privacy_security_body")
                    policySection(title: "privacy_children_title", body: "privacy_children_body")
                    policySection(title: "privacy_updates_title", body: "privacy_updates_body")
                    policySection(title: "privacy_contact_title", body: "privacy_contact_body")
                }
                .padding(24)
            }
            .navigationTitle(LocalizedStringKey("privacy_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .fontWeight(.bold)
            Text(LocalizedStringKey(body))
                .font(.body)
        }
    }
}

private enum DashboardNavItem: String, CaseIterable, Identifiable {
    case voices
    case surveys
    case teams
    case courses

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .voices:
            return "Icon_Voices"
        case .surveys:
            return "Icon_Surveys"
        case .teams:
            return "Icon_Teams"
        case .courses:
            return "Icon_Courses"
        }
    }
}

struct DashboardView: View {
    let avatarImageData: Data?
    let displayName: String
    let username: String
    let serverHost: String
    let planetCode: String
    let parentCode: String
    let authSessionCookie: String
    let onLogout: () -> Void
    @AppStorage("selected_team_name") private var selectedTeamName = ""
    @AppStorage("voices_source") private var voicesSource: VoicesSource = .community
    @State private var selectedNavItem: DashboardNavItem = .voices
    @State private var showLeftMenu = false
    @State private var showRightMenu = false
    @State private var showPrivacyPolicy = false
    @State private var showTeamsWindow = false

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLeftMenu = true
                        }
                    } label: {
                        avatarImage
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRightMenu = true
                        }
                    } label: {
                        Image("Icon_Settings")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                contentArea

                Spacer()

                HStack {
                    ForEach(DashboardNavItem.allCases) { item in
                        Button {
                            selectedNavItem = item
                        } label: {
                            Image(item.iconName)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(selectedNavItem == item ? .black : .gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())

            if showLeftMenu {
                dashboardMenuOverlay(alignment: .leading) {
                    showLeftMenu = false
                } content: {
                    leftMenuContent
                }
            }

            if showRightMenu {
                dashboardMenuOverlay(alignment: .trailing) {
                    showRightMenu = false
                } content: {
                    rightMenuContent
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTeamsWindow) {
            TeamsDashboardView(
                serverHost: serverHost,
                username: username,
                userPlanetCode: planetCode,
                authSessionCookie: authSessionCookie
            ) {
                showTeamsWindow = false
            }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let avatarImageData,
           let uiImage = UIImage(data: avatarImageData) {
            Image(uiImage: uiImage)
                .resizable()
        } else {
            Image("Img_Avatar_Empty")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.black)
        }
    }

    private func dashboardMenuOverlay(
        alignment: Alignment,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack(alignment: alignment) {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onDismiss()
                    }
                }

            Rectangle()
                .fill(Color.white)
                .frame(width: 240)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(content().clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)))
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.15), radius: 6, x: alignment == .leading ? 2 : -2, y: 0)
        }
        .transition(.move(edge: alignment == .leading ? .leading : .trailing))
    }

    private var leftMenuContent: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 25)

            avatarImage
                .scaledToFill()
                .frame(width: 128, height: 128)
                .clipShape(Circle())

            VStack(spacing: 4) {
                Text(displayName.isEmpty ? username : displayName)
                    .font(.headline)
                    .foregroundColor(.black)
                Text("@\(username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Divider()
                .background(Color.gray.opacity(0.4))

            VStack(spacing: 12) {
                Spacer()
                    .frame(height: 3)
                Button {} label: {
                    menuRow(icon: "Icon_Profile", title: "menu_profile")
                }
                Spacer()
                    .frame(height: 5)
                Button {
                    showTeamsWindow = true
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLeftMenu = false
                    }
                } label: {
                    menuRow(icon: "Icon_TeamsMenu", title: "menu_teams")
                }
                Spacer()
                    .frame(height: 3)
                Button {
                    showPrivacyPolicy = true
                } label: {
                    menuRow(icon: "Icon_Privacy", title: "menu_privacy")
                }
                Spacer()
                    .frame(height: 3)
                Button {
                    onLogout()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLeftMenu = false
                    }
                } label: {
                    menuRow(icon: "Icon_Logout", title: "logout")
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal, 16)
    }

    private func menuRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.black)
            Text(LocalizedStringKey(title))
                .foregroundColor(.black)
                .font(.body)
            Spacer()
        }
    }

    private var rightMenuContent: some View {
        VStack {
            Spacer()
        }
    }

    private var contentArea: some View {
        ZStack {
            VStack(spacing: 0) {
                Picker("Voices Source", selection: $voicesSource) {
                    Text("voices_source_community").tag(VoicesSource.community)
                    Text("voices_source_team").tag(VoicesSource.team)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                VoicesDashboardView(
                    serverHost: serverHost,
                    username: username,
                    planetCode: planetCode,
                    parentCode: parentCode,
                    authSessionCookie: authSessionCookie,
                    source: voicesSource,
                    selectedTeamName: selectedTeamName
                )
            }
            .opacity(selectedNavItem == .voices ? 1 : 0)
            .disabled(selectedNavItem != .voices)

            PlaceholderDashboardView(title: "Surveys")
                .opacity(selectedNavItem == .surveys ? 1 : 0)
                .disabled(selectedNavItem != .surveys)

            PlaceholderDashboardView(title: "Teams")
                .opacity(selectedNavItem == .teams ? 1 : 0)
                .disabled(selectedNavItem != .teams)

            PlaceholderDashboardView(title: "Courses")
                .opacity(selectedNavItem == .courses ? 1 : 0)
                .disabled(selectedNavItem != .courses)
        }
    }
}

private enum VoicesSource: String, CaseIterable, Identifiable {
    case community
    case team

    var id: String { rawValue }
}

private struct VoicesDashboardView: View {
    let serverHost: String
    let username: String
    let planetCode: String
    let parentCode: String
    let authSessionCookie: String
    let source: VoicesSource
    let selectedTeamName: String
    @State private var voices: [VoicePost] = []
    @State private var isLoading = false
    @State private var canLoadMore = true
    @State private var skip = 0
    @State private var refreshCounter = 0
    @State private var voiceToDelete: VoicePost?
    @State private var selectedVoiceForDetail: VoicePost?
    @State private var imageViewerContext: ImageViewerContext?
    @State private var localImagePaths: [String: URL] = [:]
    @State private var fabPosition: CGSize = .zero
    @State private var fabDragOffset: CGSize = .zero
    @State private var showAddVoice = false

    private struct ImageViewerContext: Identifiable {
        let id = UUID()
        let imagePaths: [String]
        let selectedIndex: Int
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if source == .team && selectedTeamName.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("voices_no_team_selected")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        if voices.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                Spacer().frame(height: 40)
                                Image("Icon_No_Voices")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(.gray.opacity(0.4))
                                Text(LocalizedStringKey("voices_no_voices_found"))
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        LazyVStack(alignment: .leading, spacing: 25) {
                            ForEach(voices) { voice in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top, spacing: 12) {
                                        avatarCircle(for: voice)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(voice.displayName)
                                                .font(.headline)
                                                .foregroundColor(.black)

                                            HStack(spacing: 6) {
                                                Text("@\(voice.username)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                Text("•")
                                                    .foregroundColor(.gray)
                                                Text(relativeTime(from: voice.timestamp))
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Spacer()
                                    }

                                    messageView(for: voice)

                                    Divider()

                                    voiceActionBar(for: voice)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedVoiceForDetail = voice
                                }
                                .onAppear {
                                    if voice.id == voices.last?.id {
                                        Task {
                                            await loadMoreVoices()
                                        }
                                    }
                                }
                            }

                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }

            draggableFAB
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
        .task(id: "\(source.rawValue)|\(selectedTeamName)|\(refreshCounter)|\(planetCode)|\(parentCode)") {
            await refreshVoicesLogic()
        }
        .refreshable {
            await refreshVoices()
        }
        .alert(
            Text("delete_voice_confirm_title"),
            isPresented: Binding(
                get: { voiceToDelete != nil },
                set: { if !$0 { voiceToDelete = nil } }
            ),
            presenting: voiceToDelete
        ) { voice in
            Button("cancel", role: .cancel) {
                voiceToDelete = nil
            }
            Button("delete", role: .destructive) {
                Task {
                    await deleteVoice(post: voice)
                }
                voiceToDelete = nil
            }
        } message: { _ in
            Text("delete_voice_confirm_message")
        }
        .sheet(item: $imageViewerContext) { context in
            ImageViewer(
                imagePaths: context.imagePaths,
                initialIndex: context.selectedIndex,
                serverHost: serverHost,
                authSessionCookie: authSessionCookie
            )
        }
        .sheet(item: $selectedVoiceForDetail) { voice in
            VoiceDetailView(
                post: voice,
                serverHost: serverHost,
                username: username,
                authSessionCookie: authSessionCookie,
                onShare: { shareVoice(post: $0) },
                onDelete: { post in
                    Task {
                        await deleteVoice(post: post)
                    }
                }
            )
        }
        .sheet(isPresented: $showAddVoice) {
            AddVoiceView {
                Task {
                    await refreshVoices()
                }
            }
        }
    }

    @MainActor
    private func refreshVoices() async {
        refreshCounter += 1
    }

    private var draggableFAB: some View {
        Button {
            showAddVoice = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: "6F6F6F"))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .offset(x: fabPosition.width + fabDragOffset.width,
                y: fabPosition.height + fabDragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    fabDragOffset = value.translation
                }
                .onEnded { value in
                    fabPosition.width += value.translation.width
                    fabPosition.height += value.translation.height
                    fabDragOffset = .zero
                }
        )
    }

    @MainActor
    private func refreshVoicesLogic() async {
        isLoading = false
        voices = []
        skip = 0
        canLoadMore = true
        await loadMoreVoices()
    }

    private func shareVoice(post: VoicePost) {
        let dateString = post.timestamp != nil ? DateFormatter.localizedString(from: post.timestamp!, dateStyle: .medium, timeStyle: .short) : ""
        let authorInfo = "\(post.displayName) (@\(post.username))"
        let header = dateString.isEmpty ? authorInfo : "\(authorInfo) - \(dateString)"

        // Remove markdown image syntax from the message for the shared text
        var cleanMessage = post.message
        let pattern = "!\\[]\\(([^\\)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(cleanMessage.startIndex..<cleanMessage.endIndex, in: cleanMessage)
            cleanMessage = regex.stringByReplacingMatches(in: cleanMessage, options: [], range: nsRange, withTemplate: "")
        }

        let shareText = """
        \(header)

        \(cleanMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        """

        var items: [Any] = [shareText]

        let paths = post.imagePaths()
        for path in paths {
            if let localURL = VoiceUIHelper.localFileURL(for: path), FileManager.default.fileExists(atPath: localURL.path) {
                items.append(localURL)
            }
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Find the active window scene and its root view controller to present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController {

            // Find the top-most view controller to present the share sheet correctly
            var topVC = rootVC
            while let presentedVC = topVC.presentedViewController {
                topVC = presentedVC
            }

            // iPad support for popovers
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.width / 2, y: topVC.view.bounds.height / 2, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            topVC.present(activityVC, animated: true)
        }
    }

    @MainActor
    private func deleteVoice(post: VoicePost) async {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/news/") else { return }

        var payload: [String: Any] = [
            "_id": post.id,
            "_deleted": true
        ]
        if let rev = post.rev { payload["_rev"] = rev }
        if let docType = post.docType { payload["docType"] = docType }
        if let createdOn = post.createdOn { payload["createdOn"] = createdOn }
        payload["message"] = post.message
        if let ts = post.timestamp {
            payload["time"] = Int64(ts.timeIntervalSince1970 * 1000)
            payload["updatedDate"] = Int64(Date().timeIntervalSince1970 * 1000)
        }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }


        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)


            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }

            _ = await MainActor.run {
                voices.removeAll { $0.id == post.id }
            }
        } catch {
        }
    }

    @MainActor
    private func loadMoreVoices() async {
        let isCommunity = source == .community
        let hasRequirements = !planetCode.isEmpty && !parentCode.isEmpty
        guard !isLoading, canLoadMore else { return }
        if isCommunity && !hasRequirements { return }

        isLoading = true
        defer { isLoading = false }


        let (newVoices, serverCount) = await fetchVoices(skip: skip, limit: 20)
        await cacheImagesForVoices(newVoices)


        if serverCount < 20 {
            canLoadMore = false
        }

        voices.append(contentsOf: newVoices)
        skip += serverCount
    }

    @MainActor
    private func fetchVoices(skip: Int, limit: Int) async -> ([VoicePost], Int) {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/news/_find") else { return ([], 0) }

        var selector: [String: Any] = [:]

        switch source {
        case .community:
            if !planetCode.isEmpty {
                selector["createdOn"] = planetCode
            }
            selector["messageType"] = "sync"
            selector["viewIn"] = [
                "$elemMatch": [
                    "section": "community",
                    "_id": "\(planetCode)@\(parentCode)"
                ]
            ]
        case .team:
            if !planetCode.isEmpty {
                selector["createdOn"] = planetCode
            }
            selector["viewIn"] = [
                "$elemMatch": [
                    "section": "teams",
                    "mode": "team",
                    "name": selectedTeamName
                ]
            ]
        }

        let requestBody: [String: Any] = [
            "selector": selector,
            "skip": skip,
            "limit": limit,
            "sort": [["time": "desc"]]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else { return ([], 0) }


        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)


            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return ([], 0)
            }

            let decoded: VoiceQueryResponse
            do {
                decoded = try JSONDecoder().decode(VoiceQueryResponse.self, from: data)
            } catch is DecodingError {
                return ([], 0)
            } catch {
                return ([], 0)
            }


            let serverCount = decoded.docs.count
            let postIds = decoded.docs.map { $0.id }
            var replyCounts: [String: Int] = [:]

            if !postIds.isEmpty {
                replyCounts = await fetchCommentCounts(for: postIds)
            }

            let posts: [VoicePost] = decoded.docs.compactMap { doc in
                // Exclude replies from the main dashboard feeds
                if let replyTo = doc.replyTo, !replyTo.isEmpty {
                    return nil
                }

                let fullName = [doc.user?.firstName, doc.user?.lastName]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                let fallbackName = doc.user?.name ?? doc.user?.userName ?? ""
                let displayName = fullName.isEmpty ? (fallbackName.isEmpty ? "Unknown" : fallbackName) : fullName
                let username = doc.user?.userName ?? (fallbackName.isEmpty ? "unknown" : fallbackName)

                let timestamp = doc.time.map { Date(timeIntervalSince1970: Double($0) / 1000) }

                return VoicePost(
                    id: doc.id,
                    rev: doc.rev,
                    message: doc.message ?? "",
                    displayName: displayName,
                    username: username,
                    timestamp: timestamp,
                    commentCount: replyCounts[doc.id, default: 0],
                    docType: doc.docType,
                    createdOn: doc.createdOn
                )
            }


            return (posts, serverCount)
        } catch {
            return ([], 0)
        }
    }

    @MainActor
    private func fetchCommentCounts(for postIds: [String]) async -> [String: Int] {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/news/_find") else { return [:] }

        let requestBody: [String: Any] = [
            "selector": ["replyTo": ["$in": postIds]],
            "fields": ["_id", "replyTo"],
            "limit": 1000
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else { return [:] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = bodyData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(VoiceQueryResponse.self, from: data)


            return decoded.docs.reduce(into: [String: Int]()) { result, doc in
                if let replyTo = doc.replyTo {
                    result[replyTo, default: 0] += 1
                }
            }
        } catch {
            return [:]
        }
    }

    private func messageView(for voice: VoicePost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(voice.parseMessageSegments()) { segment in
                if let text = segment.text {
                    Text(markdownText(from: text))
                        .font(.body)
                        .foregroundColor(.black)
                } else if let imagePath = segment.imagePath,
                          let url = resourceURL(for: imagePath) {
                    Group {
                        if let localImage = localImage(for: imagePath) {
                            Image(uiImage: localImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 160)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity, minHeight: 160)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .task {
                        await preloadImageIfNeeded(path: imagePath)
                    }
                    .onTapGesture {
                        let paths = voice.imagePaths()
                        if let index = paths.firstIndex(of: imagePath) {
                            Task {
                                // Ensure the tapped image is cached before presenting for a deterministic first open.
                                await preloadImageIfNeeded(path: imagePath)

                                _ = await MainActor.run {
                                    imageViewerContext = ImageViewerContext(
                                        imagePaths: paths,
                                        selectedIndex: index
                                    )
                                }

                                // Warm the rest in background to reduce subsequent requests.
                                let remainingPaths = paths.filter { $0 != imagePath }
                                Task {
                                    await preloadImagesIfNeeded(remainingPaths)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func resourceURL(for path: String) -> URL? {
        VoiceUIHelper.resourceURL(for: path, serverHost: serverHost)
    }

    private func preloadImagesIfNeeded(_ paths: [String]) async {
        for path in paths {
            await preloadImageIfNeeded(path: path)
        }
    }

    private func preloadImageIfNeeded(path: String) async {
        await downloadVoiceImageIfNeeded(path: path)
    }

    private func cacheImagesForVoices(_ voices: [VoicePost]) async {
        let allPaths = Set(voices.flatMap { $0.imagePaths() })
        for path in allPaths {
            await downloadVoiceImageIfNeeded(path: path)
        }
    }

    private func downloadVoiceImageIfNeeded(path: String) async {
        guard let localURL = localFileURL(for: path) else { return }

        if FileManager.default.fileExists(atPath: localURL.path),
           let data = try? Data(contentsOf: localURL),
           UIImage(data: data) != nil {
            _ = await MainActor.run {
                localImagePaths[path] = localURL
            }
            return
        }

        guard let remoteURL = resourceURL(for: path) else { return }
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  UIImage(data: data) != nil else {
                return
            }

            try data.write(to: localURL, options: .atomic)
            _ = await MainActor.run {
                localImagePaths[path] = localURL
            }

            let cacheRequest = URLRequest(url: remoteURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            let cached = CachedURLResponse(response: httpResponse, data: data)
            URLCache.shared.storeCachedResponse(cached, for: cacheRequest)
        } catch {
            return
        }
    }

    private func localFileURL(for path: String) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = caches.appendingPathComponent("VoicesImageStore", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }

        let safeName = path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "=", with: "_")
        return directory.appendingPathComponent(safeName)
    }

    private func localImage(for path: String) -> UIImage? {
        if let localURL = localImagePaths[path],
           let data = try? Data(contentsOf: localURL),
           let image = UIImage(data: data) {
            return image
        }

        guard let localURL = localFileURL(for: path),
              let data = try? Data(contentsOf: localURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func markdownText(from message: String) -> AttributedString {
        VoiceUIHelper.markdownText(from: message)
    }

    private func relativeTime(from date: Date?) -> String {
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func avatarCircle(for voice: VoicePost) -> some View {
        VoiceUIHelper.avatarCircle(for: voice)
    }

    private func voiceActionBar(for voice: VoicePost) -> some View {
        HStack(spacing: 12) {
            actionButton(icon: "Icon_Action_Comment", count: voice.commentCount) {
                selectedVoiceForDetail = voice
            }
            barDivider
            actionButton(icon: "Icon_Action_Edit")
            barDivider
            let isAuthor = voice.username == username
            actionButton(icon: "Icon_Action_Delete", isDisabled: !isAuthor) {
                voiceToDelete = voice
            }
            barDivider
            actionButton(icon: "Icon_Action_Share") {
                shareVoice(post: voice)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(
        icon: String,
        count: Int? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(isDisabled ? .gray.opacity(0.3) : .gray)
                if let count {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isDisabled)
    }

    private var barDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 20)
    }
}

private struct PlaceholderDashboardView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct VoiceDetailView: View {
    let post: VoicePost
    let serverHost: String
    let username: String
    let authSessionCookie: String
    let onShare: (VoicePost) -> Void
    let onDelete: (VoicePost) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [VoicePost] = []
    @State private var isLoading = false
    @State private var localImagePaths: [String: URL] = [:]
    @State private var imageViewerContext: ImageViewerContext?
    @State private var commentDraft = ""
    @State private var commentSelectedRange = NSRange(location: 0, length: 0)
    @State private var isSubmittingComment = false
    @AppStorage("planet_parent_code") private var planetParentCode = ""

    private struct ImageViewerContext: Identifiable {
        let id = UUID()
        let imagePaths: [String]
        let selectedIndex: Int
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Main Post
                        mainPostSection

                        Divider()

                        // Comments Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey("voices_comments_title"))
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)

                            if isLoading && comments.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20)
                            } else if comments.isEmpty {
                                Text(LocalizedStringKey("voices_no_comments"))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20)
                            } else {
                                LazyVStack(alignment: .leading, spacing: 20) {
                                    ForEach(comments) { comment in
                                        commentRow(for: comment)
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                commentComposer
                    .background(Color(.systemBackground))
            }
            .navigationTitle(LocalizedStringKey("voices_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
            }
            .task {
                await fetchComments()
            }
            .sheet(item: $imageViewerContext) { context in
                ImageViewer(
                    imagePaths: context.imagePaths,
                    initialIndex: context.selectedIndex,
                    serverHost: serverHost,
                    authSessionCookie: authSessionCookie
                )
            }
        }
    }

    private var mainPostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VoiceUIHelper.avatarCircle(for: post)

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.displayName)
                        .font(.headline)
                        .foregroundColor(.black)

                    HStack(spacing: 6) {
                        Text("@\(post.username)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(post.relativeTime())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }

            messageView(for: post)

            Divider()

            HStack(spacing: 12) {
                actionButton(icon: "Icon_Action_Comment", count: comments.isEmpty ? post.commentCount : comments.count)
                barDivider
                actionButton(icon: "Icon_Action_Edit")
                barDivider
                let isAuthor = post.username == username
                actionButton(icon: "Icon_Action_Delete", isDisabled: !isAuthor) {
                    onDelete(post)
                    dismiss()
                }
                barDivider
                actionButton(icon: "Icon_Action_Share") {
                    onShare(post)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
    }

    private func commentRow(for comment: VoicePost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VoiceUIHelper.avatarCircle(for: comment, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)

                    HStack(spacing: 4) {
                        Text("@\(comment.username)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(comment.relativeTime())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }

            messageView(for: comment)

            Divider()
                .opacity(0.5)
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func commentFormatButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.black)
        }
    }

    private func normalizedCommentSelectionRange(in nsText: NSString) -> NSRange {
        let safeLocation = min(max(commentSelectedRange.location, 0), nsText.length)
        let safeLength = min(max(commentSelectedRange.length, 0), nsText.length - safeLocation)
        return NSRange(location: safeLocation, length: safeLength)
    }

    private func commentSelectedLinesRange(in nsText: NSString) -> NSRange {
        let safeRange = normalizedCommentSelectionRange(in: nsText)
        let startLine = nsText.lineRange(for: NSRange(location: safeRange.location, length: 0))
        let endReference = safeRange.length > 0 ? max(safeRange.location, safeRange.location + safeRange.length - 1) : safeRange.location
        let endLine = nsText.lineRange(for: NSRange(location: min(endReference, nsText.length), length: 0))
        return NSRange(location: startLine.location, length: (endLine.location + endLine.length) - startLine.location)
    }

    private func applyCommentFormatting(prefix: String, suffix: String) {
        let nsText = commentDraft as NSString
        let safeRange = normalizedCommentSelectionRange(in: nsText)

        if safeRange.length > 0 {
            let selectedText = nsText.substring(with: safeRange)
            let replacement = "\(prefix)\(selectedText)\(suffix)"
            commentDraft = nsText.replacingCharacters(in: safeRange, with: replacement)
            commentSelectedRange = NSRange(location: safeRange.location + replacement.count, length: 0)
        } else {
            let replacement = "\(prefix)\(suffix)"
            commentDraft = nsText.replacingCharacters(in: safeRange, with: replacement)
            let cursorOffset = suffix.isEmpty ? replacement.count : prefix.count
            commentSelectedRange = NSRange(location: safeRange.location + cursorOffset, length: 0)
        }
    }

    private func stripCommentListPrefix(from line: String) -> String {
        if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
        if line.hasPrefix("* ") { return String(line.dropFirst(2)) }
        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        return line
    }

    private func stripCommentQuotePrefix(from line: String) -> String {
        if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
        if line.hasPrefix(">") { return String(line.dropFirst()) }
        return line
    }

    private func applyCommentBulletedListFormatting() {
        let nsText = commentDraft as NSString
        let linesRange = commentSelectedLinesRange(in: nsText)
        let block = nsText.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" { lines.removeLast() }
        let updatedLines = lines.map { "- " + stripCommentListPrefix(from: $0) }
        var replacement = updatedLines.joined(separator: "\n")
        if hasTrailingNewline { replacement += "\n" }
        commentDraft = nsText.replacingCharacters(in: linesRange, with: replacement)
        let replacementWithoutTrailingNewline = replacement.hasSuffix("\n") ? String(replacement.dropLast()) : replacement
        commentSelectedRange = NSRange(location: linesRange.location + replacementWithoutTrailingNewline.count, length: 0)
    }

    private func applyCommentNumberedListFormatting() {
        let nsText = commentDraft as NSString
        let linesRange = commentSelectedLinesRange(in: nsText)
        let block = nsText.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" { lines.removeLast() }

        var startNumber = 1
        if linesRange.location > 0 {
            let previousLineRange = nsText.lineRange(for: NSRange(location: max(0, linesRange.location - 1), length: 0))
            let previousLine = nsText.substring(with: previousLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = previousLine.range(of: #"^(\d+)\.\s"#, options: .regularExpression),
               let value = Int(previousLine[match].replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)) {
                startNumber = value + 1
            }
        }

        let updatedLines = lines.enumerated().map { idx, line in "\(startNumber + idx). " + stripCommentListPrefix(from: line) }
        var replacement = updatedLines.joined(separator: "\n")
        if hasTrailingNewline { replacement += "\n" }
        commentDraft = nsText.replacingCharacters(in: linesRange, with: replacement)
        let replacementWithoutTrailingNewline = replacement.hasSuffix("\n") ? String(replacement.dropLast()) : replacement
        commentSelectedRange = NSRange(location: linesRange.location + replacementWithoutTrailingNewline.count, length: 0)
    }

    private func applyCommentQuoteFormatting() {
        let nsText = commentDraft as NSString
        let linesRange = commentSelectedLinesRange(in: nsText)
        let block = nsText.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" { lines.removeLast() }
        let updatedLines = lines.map { "> " + stripCommentQuotePrefix(from: $0) }
        var replacement = updatedLines.joined(separator: "\n")
        if hasTrailingNewline { replacement += "\n" }
        commentDraft = nsText.replacingCharacters(in: linesRange, with: replacement)
        let replacementWithoutTrailingNewline = replacement.hasSuffix("\n") ? String(replacement.dropLast()) : replacement
        commentSelectedRange = NSRange(location: linesRange.location + replacementWithoutTrailingNewline.count, length: 0)
    }

    private func applyCommentHeaderFormatting() {
        let nsText = commentDraft as NSString
        let safeRange = normalizedCommentSelectionRange(in: nsText)
        let lineRange = nsText.lineRange(for: NSRange(location: safeRange.location, length: 0))
        let lineText = nsText.substring(with: lineRange)

        let currentPrefix: String
        if lineText.hasPrefix("### ") { currentPrefix = "### " }
        else if lineText.hasPrefix("## ") { currentPrefix = "## " }
        else if lineText.hasPrefix("# ") { currentPrefix = "# " }
        else { currentPrefix = "" }

        let nextPrefix: String
        switch currentPrefix {
        case "": nextPrefix = "# "
        case "# ": nextPrefix = "## "
        case "## ": nextPrefix = "### "
        default: nextPrefix = "# "
        }

        let content = currentPrefix.isEmpty ? lineText : String(lineText.dropFirst(currentPrefix.count))
        let replacement = nextPrefix + content
        commentDraft = nsText.replacingCharacters(in: lineRange, with: replacement)

        let lineOffset = max(0, safeRange.location - lineRange.location)
        let newCursor = min(lineRange.location + nextPrefix.count + max(0, lineOffset - currentPrefix.count), lineRange.location + replacement.count)
        commentSelectedRange = NSRange(location: newCursor, length: 0)
    }

    private func handleCommentAutoListInsertion(prefix: String, location: Int) {
        let nsText = commentDraft as NSString
        let safeLocation = min(max(location, 0), nsText.length)
        let replacement = "\n\(prefix)"
        commentDraft = nsText.replacingCharacters(in: NSRange(location: safeLocation, length: 0), with: replacement)
        commentSelectedRange = NSRange(location: safeLocation + replacement.count, length: 0)
    }

    private func handleCommentAutoListExit(lineRange: NSRange) {
        let nsText = commentDraft as NSString
        let safeRange = NSRange(
            location: min(max(lineRange.location, 0), nsText.length),
            length: min(max(lineRange.length, 0), nsText.length - min(max(lineRange.location, 0), nsText.length))
        )
        let line = nsText.substring(with: safeRange)
        let lineWithoutNewline = line.hasSuffix("\n") ? String(line.dropLast()) : line

        let markerPattern = #"^(- |\* |\d+\. )$"#
        guard let markerRange = lineWithoutNewline.range(of: markerPattern, options: .regularExpression) else { return }

        let markerNsRange = NSRange(markerRange, in: lineWithoutNewline)
        let absoluteRange = NSRange(location: safeRange.location + markerNsRange.location, length: markerNsRange.length)
        commentDraft = nsText.replacingCharacters(in: absoluteRange, with: "")
        commentSelectedRange = NSRange(location: absoluteRange.location, length: 0)
    }

    private var commentComposer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                commentFormatButton(icon: "Icon_Format_Bold") { applyCommentFormatting(prefix: "**", suffix: "**") }
                commentFormatButton(icon: "Icon_Format_Italic") { applyCommentFormatting(prefix: "_", suffix: "_") }
                commentFormatButton(icon: "Icon_Format_Header") { applyCommentHeaderFormatting() }
                commentFormatButton(icon: "Icon_Format_List_Bulleted") { applyCommentBulletedListFormatting() }
                commentFormatButton(icon: "Icon_Format_List_Numbered") { applyCommentNumberedListFormatting() }
                commentFormatButton(icon: "Icon_Format_Quote") { applyCommentQuoteFormatting() }
                commentFormatButton(icon: "Icon_Format_Link") { applyCommentFormatting(prefix: "[", suffix: "](url)") }
                commentFormatButton(icon: "Icon_Format_Image") { applyCommentFormatting(prefix: "![", suffix: "](image_url)") }
                Spacer()
            }
            .frame(height: 28)

            HStack(spacing: 10) {
                MarkdownEditorTextView(
                    text: $commentDraft,
                    selectedRange: $commentSelectedRange,
                    onAutoListInsertion: handleCommentAutoListInsertion,
                    onAutoListExit: handleCommentAutoListExit
                )
                .frame(minHeight: 44, maxHeight: 88)
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

                Button {
                    Task {
                        await submitComment()
                    }
                } label: {
                    if isSubmittingComment {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color("button_primary"))
                            .clipShape(Circle())
                    }
                }
                .disabled(isSubmittingComment || commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @MainActor
    private func submitComment() async {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmittingComment else { return }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/news") else { return }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let createdOn = post.createdOn ?? ""
        let parentCode = planetParentCode
        let userId = "org.couchdb.user:\(username)"

        let payload: [String: Any] = [
            "docType": "message",
            "time": nowMs,
            "updatedDate": nowMs,
            "createdOn": createdOn,
            "parentCode": parentCode,
            "user": [
                "_id": userId,
                "userName": username,
                "name": username
            ],
            "viewIn": [["_id": "\(createdOn)@\(parentCode)", "section": "community"]],
            "messageType": "sync",
            "messagePlanetCode": createdOn,
            "message": trimmed,
            "images": [],
            "replyTo": post.id,
            "chat": false,
            "labels": []
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                commentDraft = ""
                await fetchComments()
            }
        } catch {
        }
    }

    private func messageView(for voice: VoicePost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(voice.parseMessageSegments()) { segment in
                if let text = segment.text {
                    Text(VoiceUIHelper.markdownText(from: text))
                        .font(.body)
                        .foregroundColor(.black)
                } else if let imagePath = segment.imagePath,
                          let url = VoiceUIHelper.resourceURL(for: imagePath, serverHost: serverHost) {
                    Group {
                        if let localURL = localImagePaths[imagePath],
                           let data = try? Data(contentsOf: localURL),
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        let paths = voice.imagePaths()
                        if let index = paths.firstIndex(of: imagePath) {
                            imageViewerContext = ImageViewerContext(
                                imagePaths: paths,
                                selectedIndex: index
                            )
                        }
                    }
                    .task {
                        await downloadImageIfNeeded(path: imagePath)
                    }
                }
            }
        }
    }

    private func actionButton(
        icon: String,
        count: Int? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(isDisabled ? .gray.opacity(0.3) : .gray)
                if let count = count {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isDisabled)
    }

    private var barDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 20)
    }

    @MainActor
    private func fetchComments() async {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/news/_find") else { return }

        let requestBody: [String: Any] = [
            "selector": ["replyTo": post.id],
            "sort": [["time": "asc"]]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else { return }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = bodyData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(VoiceQueryResponse.self, from: data)

            self.comments = decoded.docs.map { doc in
                let fullName = [doc.user?.firstName, doc.user?.lastName]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                let fallbackName = doc.user?.name ?? doc.user?.userName ?? "Unknown"
                let displayName = fullName.isEmpty ? fallbackName : fullName
                let username = doc.user?.userName ?? fallbackName
                let timestamp = doc.time.map { Date(timeIntervalSince1970: Double($0) / 1000) }

                return VoicePost(
                    id: doc.id,
                    rev: doc.rev,
                    message: doc.message ?? "",
                    displayName: displayName,
                    username: username,
                    timestamp: timestamp,
                    commentCount: 0,
                    docType: doc.docType,
                    createdOn: doc.createdOn
                )
            }
        } catch {
        }
    }

    private func downloadImageIfNeeded(path: String) async {
        guard let localURL = VoiceUIHelper.localFileURL(for: path) else { return }

        if FileManager.default.fileExists(atPath: localURL.path) {
            _ = await MainActor.run {
                localImagePaths[path] = localURL
            }
            return
        }

        guard let remoteURL = VoiceUIHelper.resourceURL(for: path, serverHost: serverHost) else { return }
        var request = URLRequest(url: remoteURL)
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                try data.write(to: localURL)
                _ = await MainActor.run {
                    localImagePaths[path] = localURL
                }
            }
        } catch {
        }
    }
}

private struct TeamsDashboardView: View {
    let serverHost: String
    let username: String
    let userPlanetCode: String
    let authSessionCookie: String
    let onBack: () -> Void
    @AppStorage("remembered_username") private var rememberedUsername = ""
    @AppStorage("remembered_password") private var rememberedPassword = ""
    @AppStorage("selected_team_id") private var selectedTeamId = ""
    @AppStorage("selected_team_name") private var selectedTeamName = ""
    @State private var teams: [TeamSummary] = []
    @State private var availableTeams: [AvailableTeamSummary] = []
    @State private var pendingJoinTeamIds: Set<String> = []
    @State private var recentlyLeftTeamIds: Set<String> = []
    @State private var isLoading = true
    @State private var hasStartedLoading = false
    @State private var pendingLeaveTeam: TeamSummary?

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button {
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                        }
                        Text(LocalizedStringKey("teams_title"))
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.black)
                        Spacer()
                    }

                    Text(LocalizedStringKey("teams_subtitle"))
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(LocalizedStringKey("teams_description"))
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(teams) { team in
                                HStack(spacing: 16) {
                                    teamAvatar(for: team)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(team.name)
                                            .font(.headline)
                                            .foregroundColor(.black)
                                        HStack(spacing: 4) {
                                            Text("\(team.memberCount)")
                                            Text(LocalizedStringKey("teams_members_label"))
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Button {
                                            guard !team.isLeader else { return }
                                            pendingLeaveTeam = team
                                        } label: {
                                            Image(team.isLeader ? "Icon_Team_Leader" : "Icon_Team_Exit")
                                                .resizable()
                                                .renderingMode(.template)
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                                .foregroundColor(.gray)
                                        }
                                        .buttonStyle(.plain)
                                        Button {
                                            selectedTeamId = team.id
                                            selectedTeamName = team.name
                                        } label: {
                                            Image(selectedTeamId == team.id ? "Icon_Team_Selected" : "Icon_Team_Marker")
                                                .resizable()
                                                .renderingMode(.template)
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                                .foregroundColor(.gray)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !availableTeams.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(LocalizedStringKey("teams_explore_title"))
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    Text(LocalizedStringKey("teams_explore_description"))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 8)

                                ForEach(availableTeams) { team in
                                    HStack(spacing: 16) {
                                        teamAvatar(for: team)

                                        Text(team.name)
                                            .font(.headline)
                                            .foregroundColor(.black)

                                        Spacer()

                                        Button {
                                            guard !isJoinPending(for: team.id) else { return }
                                            Task {
                                                await requestTeamMembership(team: team)
                                            }
                                        } label: {
                                            Image(isJoinPending(for: team.id) ? "Icon_Team_Pending" : "Icon_Team_Join")
                                                .resizable()
                                                .renderingMode(.template)
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                                .foregroundColor(.gray)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .onAppear {
            guard !hasStartedLoading else { return }
            hasStartedLoading = true
            isLoading = true
            teams = []
            availableTeams = []
            pendingJoinTeamIds = []
            recentlyLeftTeamIds = []
            Task {
                await loadTeams()
            }
        }
        .alert(
            Text(LocalizedStringKey("teams_leave_confirm_title")),
            isPresented: Binding(
                get: { pendingLeaveTeam != nil },
                set: { if !$0 { pendingLeaveTeam = nil } }
            ),
            presenting: pendingLeaveTeam
        ) { team in
            Button(LocalizedStringKey("cancel"), role: .cancel) {
                pendingLeaveTeam = nil
            }
            Button(LocalizedStringKey("teams_leave_confirm_action"), role: .destructive) {
                guard let membership = team.membership else {
                    pendingLeaveTeam = nil
                    return
                }
                pendingLeaveTeam = nil
                Task {
                    await leaveTeam(membership: membership)
                }
            }
        } message: { team in
            Text(String(format: NSLocalizedString("teams_leave_confirm_message", comment: ""), team.name))
        }
    }

    private func loadTeams() async {
        _ = await MainActor.run { isLoading = true }
        defer { Task { _ = await MainActor.run { isLoading = false } } }

        let memberships = await fetchMemberships()
        let joinRequests = await fetchJoinRequests()

        let actualJoinedIds = Set(memberships.map(\.teamId))

        let (_, effectiveJoinedTeamIds, _, currentPendingJoin) = await MainActor.run {
            recentlyLeftTeamIds.formIntersection(actualJoinedIds)
            let effective = memberships.filter { !recentlyLeftTeamIds.contains($0.teamId) }
            let joinedIds = effective.map(\.teamId)
            let pending = Set(joinRequests.map(\.teamId)).subtracting(recentlyLeftTeamIds)
            return (effective, joinedIds, recentlyLeftTeamIds, pending)
        }

        let exploreTeamsData = await fetchAvailableTeams(excludedTeamIds: effectiveJoinedTeamIds)

        var summaries: [TeamSummary] = []
        if !effectiveJoinedTeamIds.isEmpty {
            let teamsData = await fetchTeams(teamIds: effectiveJoinedTeamIds)
            for team in teamsData {
                let memberCount = await fetchMemberCount(teamId: team.id)
                let membership = memberships.first(where: { $0.teamId == team.id })
                let isLeader = membership?.isLeader ?? false
                summaries.append(
                    TeamSummary(
                        id: team.id,
                        name: team.name,
                        memberCount: memberCount,
                        isLeader: isLeader,
                        membership: membership
                    )
                )
            }
        }

        let sortedSummaries = summaries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let sortedExploreTeams = exploreTeamsData.map { AvailableTeamSummary(id: $0.id, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        _ = await MainActor.run {
            self.teams = sortedSummaries
            self.pendingJoinTeamIds = currentPendingJoin.union(self.pendingJoinTeamIds.subtracting(actualJoinedIds))
            self.availableTeams = sortedExploreTeams
        }
    }

    private func fetchMemberships() async -> [TeamMembership] {
        let payload = TeamsMembershipsQuery(
            selector: TeamsMembershipsQuery.Selector(
                userId: "org.couchdb.user:\(username)",
                teamType: "local",
                docType: "membership",
                status: TeamsMembershipsQuery.Selector.Status(
                    or: [
                        ["$exists": .bool(false)],
                        ["$ne": .string("archived")]
                    ]
                )
            )
        )
        let response: TeamsMembershipsResponse? = await performTeamsRequest(body: payload)
        return response?.docs ?? []
    }

    private func fetchTeams(teamIds: [String]) async -> [TeamDetails] {
        let payload = TeamsDetailsQuery(
            selector: TeamsDetailsQuery.Selector(
                status: "active",
                type: "team",
                teamType: "local",
                id: TeamsDetailsQuery.Selector.TeamIds(in: teamIds)
            )
        )
        let response: TeamsDetailsResponse? = await performTeamsRequest(body: payload)
        return response?.docs ?? []
    }

    private func fetchMemberCount(teamId: String) async -> Int {
        let payload = TeamMembersCountQuery(
            selector: TeamMembersCountQuery.Selector(
                teamId: teamId,
                docType: "membership",
                status: TeamMembersCountQuery.Selector.Status(
                    or: [
                        ["$exists": .bool(false)],
                        ["$ne": .string("archived")]
                    ]
                )
            ),
            fields: ["_id"]
        )
        let response: TeamMembersCountResponse? = await performTeamsRequest(body: payload)
        return response?.docs.count ?? 0
    }

    private func fetchAvailableTeams(excludedTeamIds: [String], skip: Int = 0, limit: Int = 25) async -> [AvailableTeamSummary] {
        let payload = TeamsExploreQuery(
            selector: TeamsExploreQuery.Selector(
                id: TeamsExploreQuery.Selector.ExcludedIds(nin: excludedTeamIds),
                status: "active",
                type: "team",
                teamType: "local"
            ),
            limit: limit,
            skip: skip
        )
        let response: TeamsExploreResponse? = await performTeamsRequest(body: payload)
        let docs = response?.docs ?? []
        return docs.map { AvailableTeamSummary(id: $0.id, name: $0.name) }
    }

    private func fetchJoinRequests() async -> [TeamJoinRequest] {
        let payload = TeamsJoinRequestsQuery(
            selector: TeamsJoinRequestsQuery.Selector(
                docType: "request",
                teamType: "local",
                userId: "org.couchdb.user:\(username)"
            )
        )
        let response: TeamsJoinRequestsResponse? = await performTeamsRequest(body: payload)
        return response?.docs ?? []
    }

    private func performTeamsRequest<T: Encodable, U: Decodable>(body: T) async -> U? {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/teams/_find") else { return nil }
        guard let bodyData = try? JSONEncoder().encode(body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        if !rememberedUsername.isEmpty, !rememberedPassword.isEmpty {
            let credentials = "\(rememberedUsername):\(rememberedPassword)"
            if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
                request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            }
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(U.self, from: data)
        } catch {
            return nil
        }
    }


    private func requestTeamMembership(team: AvailableTeamSummary) async {
        guard !isJoinPending(for: team.id) else { return }

        let payload = JoinTeamRequest(
            docType: "request",
            teamId: team.id,
            teamType: "local",
            teamPlanetCode: userPlanetCode,
            userId: "org.couchdb.user:\(username)",
            userPlanetCode: userPlanetCode,
            isLeader: false
        )

        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/teams") else { return }
        guard let bodyData = try? JSONEncoder().encode(payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        if !rememberedUsername.isEmpty, !rememberedPassword.isEmpty {
            let credentials = "\(rememberedUsername):\(rememberedPassword)"
            if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
                request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            }
        }
        request.httpBody = bodyData

        _ = await MainActor.run {
            pendingJoinTeamIds.insert(team.id)
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                _ = await MainActor.run {
                    pendingJoinTeamIds.remove(team.id)
                }
                return
            }
            _ = await MainActor.run {
                recentlyLeftTeamIds.remove(team.id)
            }
            await loadTeams()
        } catch {
            _ = await MainActor.run {
                pendingJoinTeamIds.remove(team.id)
            }
            return
        }
    }

    private func leaveTeam(membership: TeamMembership) async {
        guard let membershipId = membership.id,
              let membershipRev = membership.rev else { return }
        let payload = TeamLeaveRequest(id: membershipId, rev: membershipRev, deleted: true)
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        guard let url = URL(string: "\(baseHost)db/teams") else { return }
        guard let bodyData = try? JSONEncoder().encode(payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        if !rememberedUsername.isEmpty, !rememberedPassword.isEmpty {
            let credentials = "\(rememberedUsername):\(rememberedPassword)"
            if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
                request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            }
        }
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            let teamId = membership.teamId
            _ = await MainActor.run {
                recentlyLeftTeamIds.insert(teamId)
                if selectedTeamId == teamId {
                    selectedTeamId = ""
                    selectedTeamName = ""
                }
                onBack()
            }
        } catch {
            return
        }
    }

    private func isJoinPending(for teamId: String) -> Bool {
        pendingJoinTeamIds.contains(teamId) && !recentlyLeftTeamIds.contains(teamId)
    }

    private func teamAvatar(for team: TeamSummary) -> some View {
        let initials = team.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        return ZStack {
            Circle()
                .fill(Color("button_primary"))
                .frame(width: 44, height: 44)
            Text(initials.isEmpty ? "?" : initials)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }

    private func teamAvatar(for team: AvailableTeamSummary) -> some View {
        let initials = team.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
        return ZStack {
            Circle()
                .fill(Color("button_primary"))
                .frame(width: 44, height: 44)
            Text(initials.isEmpty ? "?" : initials)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

private struct TeamSummary: Identifiable {
    let id: String
    let name: String
    let memberCount: Int
    let isLeader: Bool
    let membership: TeamMembership?
}

private struct AvailableTeamSummary: Identifiable {
    let id: String
    let name: String
}

private struct TeamsMembershipsQuery: Encodable {
    let selector: Selector

    struct Selector: Encodable {
        let userId: String
        let teamType: String
        let docType: String
        let status: Status

        struct Status: Encodable {
            let or: [[String: EncodableValue]]

            enum CodingKeys: String, CodingKey {
                case or = "$or"
            }
        }
    }
}

private struct TeamsMembershipsResponse: Decodable {
    let docs: [TeamMembership]
}

private struct TeamMembership: Decodable {
    let id: String?
    let rev: String?
    let teamId: String
    let role: String?
    let roles: [String]?
    let isLeaderFlag: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case teamId
        case role
        case roles
        case isLeaderFlag = "isLeader"
    }

    var isLeader: Bool {
        if let isLeaderFlag {
            return isLeaderFlag
        }
        let normalizedRoles = (roles ?? [])
            .map { $0.lowercased() }
        if normalizedRoles.contains("leader") || normalizedRoles.contains("teamleader") {
            return true
        }
        return role?.lowercased() == "leader" || role?.lowercased() == "teamleader"
    }
}

private struct TeamLeaveRequest: Encodable {
    let id: String
    let rev: String
    let deleted: Bool

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rev = "_rev"
        case deleted = "_deleted"
    }
}

private struct JoinTeamRequest: Encodable {
    let docType: String
    let teamId: String
    let teamType: String
    let teamPlanetCode: String
    let userId: String
    let userPlanetCode: String
    let isLeader: Bool
}

private struct TeamsDetailsQuery: Encodable {
    let selector: Selector

    struct Selector: Encodable {
        let status: String
        let type: String
        let teamType: String
        let id: TeamIds

        struct TeamIds: Encodable {
            let `in`: [String]

            enum CodingKeys: String, CodingKey {
                case `in` = "$in"
            }
        }

        enum CodingKeys: String, CodingKey {
            case status
            case type
            case teamType
            case id = "_id"
        }
    }
}

private struct TeamsDetailsResponse: Decodable {
    let docs: [TeamDetails]
}

private struct TeamDetails: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
    }
}

private struct TeamMembersCountQuery: Encodable {
    let selector: Selector
    let fields: [String]

    struct Selector: Encodable {
        let teamId: String
        let docType: String
        let status: Status

        struct Status: Encodable {
            let or: [[String: EncodableValue]]

            enum CodingKeys: String, CodingKey {
                case or = "$or"
            }
        }
    }
}

private struct TeamMembersCountResponse: Decodable {
    let docs: [TeamMembersCountDoc]
}

private struct TeamMembersCountDoc: Decodable {
    let id: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
    }
}

private struct TeamsExploreQuery: Encodable {
    let selector: Selector
    let limit: Int
    let skip: Int

    struct Selector: Encodable {
        let id: ExcludedIds
        let status: String
        let type: String
        let teamType: String

        struct ExcludedIds: Encodable {
            let nin: [String]

            enum CodingKeys: String, CodingKey {
                case nin = "$nin"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case status
            case type
            case teamType
        }
    }
}

private struct TeamsExploreResponse: Decodable {
    let docs: [TeamDetails]
}

private struct TeamsJoinRequestsQuery: Encodable {
    let selector: Selector

    struct Selector: Encodable {
        let docType: String
        let teamType: String
        let userId: String
    }
}

private struct TeamsJoinRequestsResponse: Decodable {
    let docs: [TeamJoinRequest]
}

private struct TeamJoinRequest: Decodable {
    let teamId: String
}

private enum EncodableValue: Encodable {
    case bool(Bool)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                EncodableValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported value")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

private struct ImageViewer: View {
    let imagePaths: [String]
    let serverHost: String
    let authSessionCookie: String
    @State private var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(imagePaths: [String], initialIndex: Int, serverHost: String, authSessionCookie: String) {
        self.imagePaths = imagePaths
        self.serverHost = serverHost
        self.authSessionCookie = authSessionCookie
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedIndex) {
                ForEach(Array(imagePaths.enumerated()), id: \.offset) { index, path in
                    ZoomableImageView(
                        url: resourceURL(for: path),
                        localFileURL: localFileURL(for: path),
                        authSessionCookie: authSessionCookie
                    )
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .background(Color.black.opacity(0.9))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func resourceURL(for path: String) -> URL? {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        let sanitizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(baseHost)db/\(sanitizedPath)")
    }

    private func localFileURL(for path: String) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = caches.appendingPathComponent("VoicesImageStore", isDirectory: true)
        let safeName = path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "=", with: "_")
        let localURL = directory.appendingPathComponent(safeName)
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }
}

private struct ZoomableImageView: View {
    let url: URL?
    let localFileURL: URL?
    let authSessionCookie: String
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var loadedImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .task(id: "\(url?.absoluteString ?? "")|\(localFileURL?.path ?? "")") {
                await loadImage()
            }
        }
    }

    private func loadImage() async {
        _ = await MainActor.run {
            isLoading = true
            loadedImage = nil
            scale = 1
            lastScale = 1
        }

        if let localFileURL,
           let data = try? Data(contentsOf: localFileURL),
           let image = UIImage(data: data) {
            _ = await MainActor.run {
                loadedImage = image
                isLoading = false
            }
            return
        }

        guard let url else {
            _ = await MainActor.run { isLoading = false }
            return
        }

        let cacheRequest = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        if let cached = URLCache.shared.cachedResponse(for: cacheRequest),
           let image = UIImage(data: cached.data) {
            _ = await MainActor.run {
                loadedImage = image
                isLoading = false
            }
            return
        } else if URLCache.shared.cachedResponse(for: cacheRequest) != nil {
            URLCache.shared.removeCachedResponse(for: cacheRequest)
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }

        for attempt in 0..<2 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let image = UIImage(data: data) else {
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        continue
                    }
                    _ = await MainActor.run { isLoading = false }
                    return
                }

                let cached = CachedURLResponse(response: httpResponse, data: data)
                URLCache.shared.storeCachedResponse(cached, for: cacheRequest)

                _ = await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
                return
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue
                }
                _ = await MainActor.run { isLoading = false }
                return
            }
        }
    }
}

struct VoicePost: Identifiable {
    let id: String
    let rev: String?
    let message: String
    let displayName: String
    let username: String
    let timestamp: Date?
    let commentCount: Int
    let docType: String?
    let createdOn: String?

    func relativeTime() -> String {
        guard let date = timestamp else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func parseMessageSegments() -> [VoiceMessageSegment] {
        let pattern = "!\\[]\\(([^\\)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [VoiceMessageSegment(text: message, imagePath: nil)]
        }
        let nsMessage = message as NSString
        let matches = regex.matches(in: message, range: NSRange(location: 0, length: nsMessage.length))
        guard !matches.isEmpty else {
            return [VoiceMessageSegment(text: message, imagePath: nil)]
        }
        var segments: [VoiceMessageSegment] = []
        var lastIndex = 0
        for match in matches {
            let matchRange = match.range(at: 0)
            if matchRange.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: matchRange.location - lastIndex)
                let text = nsMessage.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    segments.append(VoiceMessageSegment(text: text, imagePath: nil))
                }
            }
            if let pathRange = Range(match.range(at: 1), in: message) {
                let path = String(message[pathRange])
                segments.append(VoiceMessageSegment(text: nil, imagePath: path))
            }
            lastIndex = matchRange.location + matchRange.length
        }
        if lastIndex < nsMessage.length {
            let textRange = NSRange(location: lastIndex, length: nsMessage.length - lastIndex)
            let text = nsMessage.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                segments.append(VoiceMessageSegment(text: text, imagePath: nil))
            }
        }
        return segments
    }

    func imagePaths() -> [String] {
        let pattern = "!\\[]\\(([^\\)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsMessage = message as NSString
        let matches = regex.matches(in: message, range: NSRange(location: 0, length: nsMessage.length))
        return matches.compactMap { match in
            guard let pathRange = Range(match.range(at: 1), in: message) else { return nil }
            return String(message[pathRange])
        }
    }
}

struct VoiceMessageSegment: Identifiable {
    let id = UUID()
    let text: String?
    let imagePath: String?
}

enum VoiceUIHelper {
    static func localFileURL(for path: String) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = caches.appendingPathComponent("VoicesImageStore", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }

        let safeName = path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
            .replacingOccurrences(of: "=", with: "_")
        return directory.appendingPathComponent(safeName)
    }

    static func avatarCircle(for voice: VoicePost, size: CGFloat = 44) -> some View {
        let initials = voice.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
        return ZStack {
            Circle()
                .fill(Color("greenOleLogo").opacity(0.2))
                .frame(width: size, height: size)
            Text(initials.isEmpty ? "?" : initials)
                .font(size > 30 ? .subheadline : .caption)
                .fontWeight(.semibold)
                .foregroundColor(Color("darkOle"))
        }
    }

    static func markdownText(from message: String, preservingLineBreaks: Bool = false) -> AttributedString {
        let markdownHasBlockSyntax = message
            .split(separator: "\n", omittingEmptySubsequences: false)
            .contains { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty { return false }
                if line.hasPrefix("#") || line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix(">") { return true }
                if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil { return true }
                return false
            }

        let parsedMessage: String
        if preservingLineBreaks && !markdownHasBlockSyntax {
            parsedMessage = message.replacingOccurrences(of: "\n", with: "  \n")
        } else {
            parsedMessage = message
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let attributed = try? AttributedString(markdown: parsedMessage, options: options) {
            return attributed
        }
        return AttributedString(parsedMessage)
    }

    static func resourceURL(for path: String, serverHost: String) -> URL? {
        let baseHost = serverHost.hasSuffix("/") ? serverHost : "\(serverHost)/"
        let sanitizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "\(baseHost)db/\(sanitizedPath)")
    }
}

struct VoiceQueryResponse: Decodable {
    let docs: [VoiceDocument]

    struct VoiceDocument: Decodable {
        let id: String
        let rev: String?
        let message: String?
        let user: UserSummary?
        let time: Int64?
        let messageType: String?
        let replyTo: String?
        let docType: String?
        let createdOn: String?

        struct UserSummary: Decodable {
            let name: String?
            let userName: String?
            let firstName: String?
            let lastName: String?
        }

        private enum CodingKeys: String, CodingKey {
            case id = "_id"
            case rev = "_rev"
            case message
            case user
            case time
            case messageType
            case replyTo
            case docType
            case createdOn
        }
    }
}

struct ServerSelectorView: View {
    @Binding var selectedServerHost: String
    let customServers: [CustomServer]
    let onAddServerTap: () -> Void
    let onClearServersTap: () -> Void
    @State private var lastSelectedHost: String
    @State private var showClearServersConfirmation = false

    init(
        selectedServerHost: Binding<String>,
        customServers: [CustomServer],
        onAddServerTap: @escaping () -> Void,
        onClearServersTap: @escaping () -> Void
    ) {
        _selectedServerHost = selectedServerHost
        self.customServers = customServers
        self.onAddServerTap = onAddServerTap
        self.onClearServersTap = onClearServersTap
        _lastSelectedHost = State(initialValue: selectedServerHost.wrappedValue)
    }

    var body: some View {
        let combinedServers = ServerOption.defaultServers
            + customServers.map { ServerOption(host: $0.host, displayName: $0.name, flag: $0.flag) }
            + [ServerOption(host: ServerOption.clearServersHost, displayName: "clear_servers", flag: nil)]
            + [ServerOption(host: ServerOption.addServerHost, displayName: "add_server", flag: nil)]

        Picker(
            selection: $selectedServerHost,
            label: serverLabel(for: selectedServerHost)
        ) {
            ForEach(combinedServers) { server in
                serverRow(for: server)
                .tag(server.host)
            }
        }
        .pickerStyle(.menu)
        .tint(.black)
        .environment(\.colorScheme, .light)
        .onChange(of: selectedServerHost) { _, newValue in
            if newValue == ServerOption.clearServersHost {
                selectedServerHost = lastSelectedHost
                showClearServersConfirmation = true
            } else if newValue == ServerOption.addServerHost {
                selectedServerHost = lastSelectedHost
                onAddServerTap()
            } else {
                lastSelectedHost = newValue
            }
        }
        .alert("clear_servers_title", isPresented: $showClearServersConfirmation) {
            Button("cancel", role: .cancel) {}
            Button("clear_servers_confirm", role: .destructive) {
                onClearServersTap()
            }
        } message: {
            Text("clear_servers_message")
        }
    }

    @ViewBuilder
    private func serverLabel(for host: String) -> some View {
        let combinedServers = ServerOption.defaultServers
            + customServers.map { ServerOption(host: $0.host, displayName: $0.name, flag: $0.flag) }
            + [ServerOption(host: ServerOption.clearServersHost, displayName: "clear_servers", flag: nil)]
            + [ServerOption(host: ServerOption.addServerHost, displayName: "add_server", flag: nil)]
        if let server = combinedServers.first(where: { $0.host == host }) {
            serverRow(for: server)
        } else {
            Text("Select")
                .foregroundColor(.black)
        }
    }

    @ViewBuilder
    private func serverRow(for server: ServerOption) -> some View {
        if let flag = server.flag {
            Text(flag + " - " + server.displayName)
                .foregroundStyle(.black)
        } else {
            Text(LocalizedStringKey(server.displayName))
                .foregroundStyle(.black)
        }
    }
}

struct AddServerView: View {
    private static let excludedRegionCodes: Set<String> = ["CN", "IL", "PS", "EZ", "QO"]
    private static let regionIdentifiers = Locale.Region.isoRegions.map { $0.identifier }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selectedFlag = "🇬🇹"
    @State private var serverName = ""
    @State private var serverHost = ""
    @State private var showServerHostError = false
    let onAdd: (CustomServer) -> Void
    private var flagOptions: [FlagOption] {
        var options: [FlagOption] = []
        for code in AddServerView.regionIdentifiers {
            if AddServerView.excludedRegionCodes.contains(code) {
                continue
            }
            if !AddServerView.isAlpha2RegionCode(code) {
                continue
            }
            guard let name = locale.localizedString(forRegionCode: code) else {
                continue
            }
            options.append(
                FlagOption(
                    code: code,
                    name: name,
                    emoji: AddServerView.flagEmoji(for: code)
                )
            )
        }
        return options.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("select_flag")) {
                    Picker("select_flag", selection: $selectedFlag) {
                        ForEach(flagOptions) { option in
                            Text(option.emoji + " " + option.name)
                                .tag(option.emoji)
                        }
                    }
                }

                Section(header: Text("server_name")) {
                    TextField("server_name", text: $serverName)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("server_host")) {
                    TextField("server_host", text: $serverHost)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if showServerHostError {
                        Text(LocalizedStringKey("server_host_error"))
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("add_server_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("add_to_list") {
                        let trimmedHost = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !isValidServerHost(trimmedHost) {
                            showServerHostError = true
                            return
                        }

                        showServerHostError = false
                        let newServer = CustomServer(
                            flag: selectedFlag,
                            name: trimmedName,
                            host: trimmedHost
                        )
                        onAdd(newServer)
                        dismiss()
                    }
                    .disabled(serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private static func isAlpha2RegionCode(_ code: String) -> Bool {
        code.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil
    }

    static func flagEmoji(for regionCode: String) -> String {
        let base: UInt32 = 127397
        return regionCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    private func isValidServerHost(_ host: String) -> Bool {
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            return true
        }

        let ipPattern = #"^\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?$"#
        if host.range(of: ipPattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }
}

struct LanguagePickerView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss

    private let languages: [LanguageOption] = [
        LanguageOption(code: "en", displayName: "English"),
        LanguageOption(code: "es", displayName: "Español"),
        LanguageOption(code: "fr", displayName: "Français"),
        LanguageOption(code: "pt", displayName: "Português"),
        LanguageOption(code: "ne", displayName: "नेपाली"),
        LanguageOption(code: "ar", displayName: "العربية"),
        LanguageOption(code: "so", displayName: "Soomaali"),
        LanguageOption(code: "hi", displayName: "हिन्दी")
    ]

    var body: some View {
        NavigationStack {
            List(languages) { language in
                Button {
                    selectedLanguage = language.code
                    dismiss()
                } label: {
                    HStack {
                        Text(language.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        if language.code == selectedLanguage {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Language")
        }
    }
}

struct LanguageOption: Identifiable {
    let code: String
    let displayName: String

    var id: String { code }
}

struct FlagOption: Identifiable {
    let code: String
    let name: String
    let emoji: String

    var id: String { code }
}

struct ServerOption: Identifiable {
    let host: String
    let displayName: String
    let flag: String?

    var id: String { host }

    static let defaultServers: [ServerOption] = [
        ServerOption(
            host: "http://10.82.1.30/",
            displayName: "Xela",
            flag: "🇬🇹"
        ),
        ServerOption(
            host: "https://planet.gt/",
            displayName: "Guatemala",
            flag: "🇬🇹"
        ),
        ServerOption(
            host: "https://sanpablo.planet.gt/",
            displayName: "San Pablo",
            flag: "🇬🇹"
        ),
        ServerOption(
            host: "https://planet.somalia.ole.org",
            displayName: "Somalia",
            flag: "🇸🇴"
        ),
        ServerOption(
            host: "https://planet.learning.ole.org/",
            displayName: "Learning",
            flag: "🇺🇸"
        ),
        ServerOption(
            host: "https://planet.earth.ole.org/",
            displayName: "Earth",
            flag: "🇺🇸"
        ),
        ServerOption(
            host: "https://planet.vi.ole.org/",
            displayName: "VI",
            flag: "🇺🇸"
        ),
        ServerOption(
            host: "https://planet.uriur.ole.org/",
            displayName: "Uriur",
            flag: "🇰🇪"
        )
    ]

    static let addServerHost = "add_server"
    static let clearServersHost = "clear_servers"
    static let guatemala = ServerOption(
        host: "https://planet.gt/",
        displayName: "Guatemala",
        flag: "🇬🇹"
    )
}

struct CustomServer: Identifiable, Codable {
    let id: UUID
    let flag: String
    let name: String
    let host: String

    init(id: UUID = UUID(), flag: String, name: String, host: String) {
        self.id = id
        self.flag = flag
        self.name = name
        self.host = host
    }
}

private enum AppTiming {
    static let animationTotal: Double = 1.15
}

private enum AppStrings {
    static let appName = "myPlanet"
    static let appVariant = "Lite"
    static let appVersion = "0.0.1 Beta"
    static let poweredBy = "Powered by"
    static let companyName = "Plataformas Informáticas"
    static let companyUrl = "http://plataformasinformaticas.com"
}

private struct AddVoiceView: View {
    let onVoicePublished: () -> Void

    private struct SelectedPostImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("server_host") private var selectedServerHost = ""
    @AppStorage("auth_session") private var authSessionCookie = ""
    @AppStorage("profile_username") private var profileUsername = ""
    @AppStorage("profile_display_name") private var profileDisplayName = ""
    @AppStorage("planet_code") private var planetCode = ""
    @AppStorage("planet_parent_code") private var planetParentCode = ""
    @AppStorage("selected_team_name") private var selectedTeamName = ""
    @AppStorage("voices_source") private var voicesSourceRawValue = VoicesSource.community.rawValue

    @State private var messageText = ""
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var isShowingLinkSheet = false
    @State private var linkTitleInput = ""
    @State private var linkURLInput = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPostImages: [SelectedPostImage] = []
    @State private var previewingPostImage: SelectedPostImage?
    @State private var isPublishing = false
    @State private var publishErrorMessage: String?

    private func formatButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.black)
        }
    }

    private struct UploadedImageInfo {
        let resourceId: String
        let filename: String
        let markdown: String
    }

    private var isCommunitySource: Bool {
        voicesSourceRawValue == VoicesSource.community.rawValue
    }

    private var canPublishVoice: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !selectedPostImages.isEmpty
        return !isPublishing && (hasText || hasImages)
    }

    private func applyFormatting(prefix: String, suffix: String) {
        let nsText = messageText as NSString
        let safeLocation = min(max(selectedRange.location, 0), nsText.length)
        let safeLength = min(max(selectedRange.length, 0), nsText.length - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)

        if safeRange.length > 0 {
            let selectedText = nsText.substring(with: safeRange)
            let replacement = "\(prefix)\(selectedText)\(suffix)"
            messageText = nsText.replacingCharacters(in: safeRange, with: replacement)
            selectedRange = NSRange(location: safeRange.location + replacement.count, length: 0)
        } else {
            let replacement = "\(prefix)\(suffix)"
            messageText = nsText.replacingCharacters(in: safeRange, with: replacement)

            let cursorOffset = suffix.isEmpty ? replacement.count : prefix.count
            selectedRange = NSRange(location: safeRange.location + cursorOffset, length: 0)
        }
    }

    private func presentLinkSheet() {
        let nsText = messageText as NSString
        let safeRange = normalizedSelectionRange(in: nsText)

        if safeRange.length > 0 {
            linkTitleInput = nsText.substring(with: safeRange)
        } else {
            linkTitleInput = ""
        }
        linkURLInput = ""
        isShowingLinkSheet = true
    }

    private func applyLinkFromSheet() {
        let trimmedURL = linkURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        let nsText = messageText as NSString
        let safeRange = normalizedSelectionRange(in: nsText)
        let selectedText = safeRange.length > 0 ? nsText.substring(with: safeRange) : ""

        let trimmedTitle = linkTitleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkTitle = trimmedTitle.isEmpty ? (selectedText.isEmpty ? trimmedURL : selectedText) : trimmedTitle
        let replacement = "[\(linkTitle)](\(trimmedURL))"

        messageText = nsText.replacingCharacters(in: safeRange, with: replacement)
        selectedRange = NSRange(location: safeRange.location + replacement.count, length: 0)

        isShowingLinkSheet = false
        linkTitleInput = ""
        linkURLInput = ""
    }

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        var images: [SelectedPostImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                images.append(SelectedPostImage(image: uiImage))
            }
        }

        await MainActor.run {
            selectedPostImages = images
        }
    }

    private func removeSelectedPhoto(id: UUID) {
        guard let imageIndex = selectedPostImages.firstIndex(where: { $0.id == id }) else {
            return
        }

        selectedPostImages.remove(at: imageIndex)
        if selectedPhotoItems.indices.contains(imageIndex) {
            selectedPhotoItems.remove(at: imageIndex)
        }
    }

    private func buildBaseHost() -> String {
        selectedServerHost.hasSuffix("/") ? selectedServerHost : "\(selectedServerHost)/"
    }

    private func timestampFileName(index: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmssSSS"
        let base = formatter.string(from: Date())
        return "post\(base)\(index).jpg"
    }

    private func authorizedRequest(url: URL, method: String, contentType: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if !authSessionCookie.isEmpty {
            request.setValue("AuthSession=\(authSessionCookie)", forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private func jsonString(from object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func jsonString(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let text = String(data: pretty, encoding: .utf8) else {
            return String(data: data, encoding: .utf8) ?? "<non-utf8-response>"
        }
        return text
    }

    private func logRequest(name: String, endpoint: URL, payload: Any) {
        appLog("--- [AddVoice] \(name) Request ---")
        appLog("Endpoint: \(endpoint.absoluteString)")
        appLog("Payload(JSON):\n\(jsonString(from: payload))")
    }

    private func logResponse(name: String, response: URLResponse, data: Data) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        appLog("--- [AddVoice] \(name) Response ---")
        appLog("Status: \(status)")
        appLog("Body(JSON/Text):\n\(jsonString(from: data))")
    }

    private func fetchUserDocument(username: String) async throws -> [String: Any] {
        let baseHost = buildBaseHost()
        let userId = "org.couchdb.user:\(username)"
        let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId

        guard let userURL = URL(string: "\(baseHost)db/_users/\(encodedUserId)") else {
            throw NSError(domain: "AddVoice", code: 8, userInfo: [NSLocalizedDescriptionKey: "URL de usuario inválida"])
        }

        let payload: [String: Any] = ["_id": userId]
        logRequest(name: "Fetch User Document", endpoint: userURL, payload: payload)

        let request = authorizedRequest(url: userURL, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        logResponse(name: "Fetch User Document", response: response, data: data)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "AddVoice", code: 9, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener el usuario para crear voz"])
        }

        guard let userJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AddVoice", code: 10, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida de usuario"])
        }

        return userJSON
    }

    private func ensureValidPublishInput() -> Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImages = !selectedPostImages.isEmpty
        if hasText || hasImages {
            return true
        }
        publishErrorMessage = "Debes agregar al menos texto o una imagen para publicar."
        return false
    }

    private func prepareImagesForPosting() async throws -> [UploadedImageInfo] {
        let baseHost = buildBaseHost()
        guard let resourcesURL = URL(string: "\(baseHost)db/resources") else {
            throw NSError(domain: "AddVoice", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL de recursos inválida"])
        }

        var uploaded: [UploadedImageInfo] = []

        for (index, selectedImage) in selectedPostImages.enumerated() {
            guard let imageData = selectedImage.image.jpegData(compressionQuality: 0.85) else { continue }

            let fileName = timestampFileName(index: index)
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let addedBy = profileUsername.isEmpty ? "unknown" : profileUsername

            let metadata: [String: Any] = [
                "title": fileName,
                "createdDate": nowMs,
                "filename": fileName,
                "private": false,
                "addedBy": addedBy,
                "resideOn": planetParentCode,
                "sourcePlanet": planetCode,
                "androidId": UIDevice.current.identifierForVendor?.uuidString ?? "",
                "deviceName": UIDevice.current.model,
                "customDeviceName": UIDevice.current.name,
                "mediaType": "image",
                "privateFor": "community"
            ]

            logRequest(name: "Create Resource Metadata", endpoint: resourcesURL, payload: metadata)

            var metadataRequest = authorizedRequest(url: resourcesURL, method: "POST", contentType: "application/json")
            metadataRequest.httpBody = try JSONSerialization.data(withJSONObject: metadata)

            let (metadataData, metadataResponse) = try await URLSession.shared.data(for: metadataRequest)
            logResponse(name: "Create Resource Metadata", response: metadataResponse, data: metadataData)
            guard let metadataHTTP = metadataResponse as? HTTPURLResponse, (200...299).contains(metadataHTTP.statusCode) else {
                throw NSError(domain: "AddVoice", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear metadata de imagen"])
            }

            guard let metadataJSON = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] else {
                throw NSError(domain: "AddVoice", code: 3, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida al crear recurso"])
            }

            let resourceId = (metadataJSON["id"] as? String) ?? (metadataJSON["_id"] as? String)
            let revision = (metadataJSON["rev"] as? String) ?? (metadataJSON["_rev"] as? String)

            guard let resourceId, let revision else {
                throw NSError(domain: "AddVoice", code: 3, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida al crear recurso"])
            }

            guard let uploadURL = URL(string: "\(baseHost)db/resources/\(resourceId)/\(fileName)") else {
                throw NSError(domain: "AddVoice", code: 4, userInfo: [NSLocalizedDescriptionKey: "URL de subida inválida"])
            }

            appLog("--- [AddVoice] Upload Resource Binary Request ---")
            appLog("Endpoint: \(uploadURL.absoluteString)")
            appLog("Headers(JSON): {\"If-Match\": \"\(revision)\", \"Content-Type\": \"application/octet-stream\"}")
            appLog("Body Bytes: \(imageData.count)")

            var uploadRequest = authorizedRequest(url: uploadURL, method: "PUT", contentType: "application/octet-stream")
            uploadRequest.setValue(revision, forHTTPHeaderField: "If-Match")
            uploadRequest.httpBody = imageData

            let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
            logResponse(name: "Upload Resource Binary", response: uploadResponse, data: uploadData)
            guard let uploadHTTP = uploadResponse as? HTTPURLResponse, (200...299).contains(uploadHTTP.statusCode) else {
                throw NSError(domain: "AddVoice", code: 5, userInfo: [NSLocalizedDescriptionKey: "No se pudo subir imagen"])
            }

            var finalFilename = fileName
            if let uploadJSON = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any] {
                if let value = uploadJSON["filename"] as? String, !value.isEmpty {
                    finalFilename = value
                } else if let value = uploadJSON["fileName"] as? String, !value.isEmpty {
                    finalFilename = value
                } else if let value = uploadJSON["name"] as? String, !value.isEmpty {
                    finalFilename = value
                }
            }

            let markdown = "![](resources/\(resourceId)/\(finalFilename))"
            uploaded.append(UploadedImageInfo(resourceId: resourceId, filename: finalFilename, markdown: markdown))
        }

        return uploaded
    }

    private func createVoice(message: String, uploadedImages: [UploadedImageInfo]) async throws {
        let baseHost = buildBaseHost()
        guard let newsURL = URL(string: "\(baseHost)db/news") else {
            throw NSError(domain: "AddVoice", code: 6, userInfo: [NSLocalizedDescriptionKey: "URL de creación de voz inválida"])
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let username = profileUsername.isEmpty ? "unknown" : profileUsername
        let userDocument = try await fetchUserDocument(username: username)

        let viewIn: [[String: Any]] = isCommunitySource
            ? [["section": "community", "_id": "\(planetCode)@\(planetParentCode)"]]
            : [["section": "teams", "mode": "team", "name": selectedTeamName]]

        appLog("[AddVoice] Publishing target viewIn: \(jsonString(from: viewIn))")

        let payload: [String: Any] = [
            "chat": false,
            "message": message,
            "time": nowMs,
            "updatedDate": nowMs,
            "createdOn": planetCode,
            "docType": "message",
            "viewIn": viewIn,
            "avatar": "",
            "messageType": "sync",
            "messagePlanetCode": planetCode,
            "replyTo": NSNull(),
            "parentCode": planetParentCode,
            "images": uploadedImages.map { ["resourceId": $0.resourceId, "filename": $0.filename, "markdown": $0.markdown] },
            "labels": [],
            "user": userDocument,
            "news": true
        ]

        logRequest(name: "Create Voice", endpoint: newsURL, payload: payload)

        var request = authorizedRequest(url: newsURL, method: "POST", contentType: "application/json")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        logResponse(name: "Create Voice", response: response, data: responseData)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "AddVoice", code: 7, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear la voz"])
        }
    }

    @MainActor
    private func handlePublishVoice() async {
        guard ensureValidPublishInput(), !isPublishing else { return }

        isPublishing = true
        defer { isPublishing = false }

        do {
            appLog("[AddVoice] Start publish flow")
            let uploadedImages = try await prepareImagesForPosting()
            let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            let imageMarkdown = uploadedImages.map(\.markdown).joined(separator: "\n")
            let finalMessage: String

            if text.isEmpty {
                finalMessage = imageMarkdown
            } else if imageMarkdown.isEmpty {
                finalMessage = text
            } else {
                finalMessage = "\(text)\n\n\(imageMarkdown)"
            }

            try await createVoice(message: finalMessage, uploadedImages: uploadedImages)
            appLog("[AddVoice] Publish flow completed successfully")
            onVoicePublished()
            dismiss()
        } catch {
            appLog("[AddVoice] Publish flow failed: \(error.localizedDescription)")
            publishErrorMessage = error.localizedDescription
        }
    }

    private func normalizedSelectionRange(in nsText: NSString) -> NSRange {
        let safeLocation = min(max(selectedRange.location, 0), nsText.length)
        let safeLength = min(max(selectedRange.length, 0), nsText.length - safeLocation)
        return NSRange(location: safeLocation, length: safeLength)
    }

    private func selectedLinesRange(in nsText: NSString) -> NSRange {
        let safeRange = normalizedSelectionRange(in: nsText)
        let startLine = nsText.lineRange(for: NSRange(location: safeRange.location, length: 0))

        let endReference = safeRange.length > 0 ? max(safeRange.location, safeRange.location + safeRange.length - 1) : safeRange.location
        let endLine = nsText.lineRange(for: NSRange(location: min(endReference, nsText.length), length: 0))

        return NSRange(location: startLine.location, length: (endLine.location + endLine.length) - startLine.location)
    }

    private func stripListPrefix(from line: String) -> String {
        let trimmed = line
        if trimmed.hasPrefix("- ") {
            return String(trimmed.dropFirst(2))
        }
        if trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        }
        if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return String(trimmed[match.upperBound...])
        }
        return line
    }


    private func stripQuotePrefix(from line: String) -> String {
        if line.hasPrefix("> ") {
            return String(line.dropFirst(2))
        }
        if line.hasPrefix(">") {
            return String(line.dropFirst())
        }
        return line
    }

    private func applyBulletedListFormatting() {
        let nsText = messageText as NSString
        let linesRange = selectedLinesRange(in: nsText)
        let block = nsText.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")

        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" {
            lines.removeLast()
        }

        let updatedLines = lines.map { "- " + stripListPrefix(from: $0) }
        var replacement = updatedLines.joined(separator: "\n")
        if hasTrailingNewline {
            replacement += "\n"
        }

        messageText = nsText.replacingCharacters(in: linesRange, with: replacement)

        let replacementWithoutTrailingNewline = replacement.hasSuffix("\n") ? String(replacement.dropLast()) : replacement
        selectedRange = NSRange(location: linesRange.location + replacementWithoutTrailingNewline.count, length: 0)
    }

    private func applyNumberedListFormatting() {
        let nsText = messageText as NSString
        let linesRange = selectedLinesRange(in: nsText)
        let block = nsText.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")

        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" {
            lines.removeLast()
        }

        var startNumber = 1
        if linesRange.location > 0 {
            let previousLineRange = nsText.lineRange(for: NSRange(location: max(0, linesRange.location - 1), length: 0))
            let previousLine = nsText.substring(with: previousLineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = previousLine.range(of: #"^(\d+)\.\s"#, options: .regularExpression),
               let value = Int(previousLine[match].replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)) {
                startNumber = value + 1
            }
        }

        let updatedLines = lines.enumerated().map { index, line in
            "\(startNumber + index). " + stripListPrefix(from: line)
        }

        var replacement = updatedLines.joined(separator: "\n")
        if hasTrailingNewline {
            replacement += "\n"
        }

        messageText = nsText.replacingCharacters(in: linesRange, with: replacement)

        let replacementWithoutTrailingNewline = replacement.hasSuffix("\n") ? String(replacement.dropLast()) : replacement
        selectedRange = NSRange(location: linesRange.location + replacementWithoutTrailingNewline.count, length: 0)
    }

    private func applyQuoteFormatting() {
        let nsText = messageText as NSString
        let linesRange = selectedLinesRange(in: nsText)
        let block = nsText.substring(with: linesRange)
        let hasTrailingNewline = block.hasSuffix("\n")

        var lines = block.components(separatedBy: "\n")
        if hasTrailingNewline, lines.last == "" {
            lines.removeLast()
        }

        let updatedLines = lines.map { "> " + stripQuotePrefix(from: $0) }
        var replacement = updatedLines.joined(separator: "\n")
        if hasTrailingNewline {
            replacement += "\n"
        }

        messageText = nsText.replacingCharacters(in: linesRange, with: replacement)

        let replacementWithoutTrailingNewline = replacement.hasSuffix("\n") ? String(replacement.dropLast()) : replacement
        selectedRange = NSRange(location: linesRange.location + replacementWithoutTrailingNewline.count, length: 0)
    }

    private func applyHeaderFormatting() {
        let nsText = messageText as NSString
        let safeLocation = min(max(selectedRange.location, 0), nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineText = nsText.substring(with: lineRange)

        let currentPrefix: String
        if lineText.hasPrefix("### ") {
            currentPrefix = "### "
        } else if lineText.hasPrefix("## ") {
            currentPrefix = "## "
        } else if lineText.hasPrefix("# ") {
            currentPrefix = "# "
        } else {
            currentPrefix = ""
        }

        let newPrefix: String
        switch currentPrefix {
        case "":
            newPrefix = "# "
        case "# ":
            newPrefix = "## "
        default:
            newPrefix = "### "
        }

        let contentWithoutPrefix = String(lineText.dropFirst(currentPrefix.count))
        let updatedLineText = newPrefix + contentWithoutPrefix
        messageText = nsText.replacingCharacters(in: lineRange, with: updatedLineText)

        let delta = newPrefix.count - currentPrefix.count
        let newCursorLocation = min(max(0, safeLocation + delta), messageText.count)
        selectedRange = NSRange(location: newCursorLocation, length: 0)
    }



    private func handleAutoListInsertion(prefix: String, location: Int) {
        let nsText = messageText as NSString
        let safeLocation = min(max(location, 0), nsText.length)
        let insertion = "\n\(prefix)"
        messageText = nsText.replacingCharacters(in: NSRange(location: safeLocation, length: 0), with: insertion)
        selectedRange = NSRange(location: safeLocation + insertion.count, length: 0)
    }

    private func handleAutoListExit(lineRange: NSRange) {
        let nsText = messageText as NSString
        let safeLocation = min(max(lineRange.location, 0), nsText.length)
        let safeLength = min(max(lineRange.length, 0), nsText.length - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)

        let rawLine = nsText.substring(with: safeRange)
        let lineWithoutNewline = rawLine.replacingOccurrences(of: "\n", with: "")

        let markerToRemove: String?
        let trimmedLine = lineWithoutNewline.trimmingCharacters(in: .whitespaces)
        if trimmedLine == "-" {
            markerToRemove = "- "
        } else if trimmedLine == "*" {
            markerToRemove = "* "
        } else if let _ = trimmedLine.range(of: #"^\d+\.$"#, options: .regularExpression) {
            markerToRemove = lineWithoutNewline.trimmingCharacters(in: .whitespaces) + " "
        } else {
            markerToRemove = nil
        }

        guard let marker = markerToRemove,
              let markerRange = lineWithoutNewline.range(of: marker) else {
            return
        }

        let markerNsRange = NSRange(markerRange, in: lineWithoutNewline)
        let absoluteRange = NSRange(location: safeRange.location + markerNsRange.location, length: markerNsRange.length)
        messageText = nsText.replacingCharacters(in: absoluteRange, with: "")
        selectedRange = NSRange(location: absoluteRange.location, length: 0)
    }


    private enum PreviewLineKind {
        case empty
        case h1(String)
        case h2(String)
        case h3(String)
        case bullet(String)
        case numbered(number: String, content: String)
        case quote(String)
        case plain(String)
    }

    private func previewKind(for rawLine: String) -> PreviewLineKind {
        if rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .empty
        }

        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("### ") {
            return .h3(String(trimmed.dropFirst(4)))
        }
        if trimmed.hasPrefix("## ") {
            return .h2(String(trimmed.dropFirst(3)))
        }
        if trimmed.hasPrefix("# ") {
            return .h1(String(trimmed.dropFirst(2)))
        }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return .bullet(String(trimmed.dropFirst(2)))
        }
        if trimmed.hasPrefix("> ") {
            return .quote(String(trimmed.dropFirst(2)))
        }
        if trimmed == ">" {
            return .quote("")
        }

        if let dotIndex = trimmed.firstIndex(of: ".") {
            let numberPart = trimmed[..<dotIndex]
            let contentStart = trimmed.index(after: dotIndex)
            if numberPart.allSatisfy(\.isNumber), contentStart < trimmed.endIndex, trimmed[contentStart] == " " {
                let content = String(trimmed[trimmed.index(after: contentStart)...])
                return .numbered(number: String(numberPart), content: content)
            }
        }

        return .plain(rawLine)
    }

    @ViewBuilder
    private func previewLineView(_ rawLine: String) -> some View {
        switch previewKind(for: rawLine) {
        case .empty:
            Text(" ")
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .h1(content):
            Text(VoiceUIHelper.markdownText(from: content))
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .h2(content):
            Text(VoiceUIHelper.markdownText(from: content))
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .h3(content):
            Text(VoiceUIHelper.markdownText(from: content))
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .bullet(content):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(VoiceUIHelper.markdownText(from: content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .numbered(number, content):
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                Text(VoiceUIHelper.markdownText(from: content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .quote(content):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 3)
                Text(VoiceUIHelper.markdownText(from: content))
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .plain(content):
            Text(VoiceUIHelper.markdownText(from: content))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var previewContentView: some View {
        let lines = messageText.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                previewLineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var publishButton: some View {
        Button {
            Task {
                await handlePublishVoice()
            }
        } label: {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(LocalizedStringKey("voices_add_publish_button"))
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canPublishVoice ? Color("button_primary") : Color.gray.opacity(0.5))
            .cornerRadius(12)
        }
        .disabled(!canPublishVoice)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    Text(LocalizedStringKey("voices_add_subtitle"))
                        .font(.headline)
                        .foregroundColor(.black)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("voices_add_editor_hint"))
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        MarkdownEditorTextView(
                            text: $messageText,
                            selectedRange: $selectedRange,
                            onAutoListInsertion: handleAutoListInsertion,
                            onAutoListExit: handleAutoListExit
                        )
                            .frame(minHeight: 150)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Options Bar
                    HStack(spacing: 15) {
                        formatButton(icon: "Icon_Format_Bold") {
                            applyFormatting(prefix: "**", suffix: "**")
                        }
                        formatButton(icon: "Icon_Format_Italic") {
                            applyFormatting(prefix: "_", suffix: "_")
                        }
                        formatButton(icon: "Icon_Format_Header") {
                            applyHeaderFormatting()
                        }
                        formatButton(icon: "Icon_Format_List_Bulleted") {
                            applyBulletedListFormatting()
                        }
                        formatButton(icon: "Icon_Format_List_Numbered") {
                            applyNumberedListFormatting()
                        }
                        formatButton(icon: "Icon_Format_Quote") {
                            applyQuoteFormatting()
                        }
                        formatButton(icon: "Icon_Format_Link") {
                            presentLinkSheet()
                        }
                        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                            Image("Icon_Format_Image")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .frame(height: 40)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(LocalizedStringKey("voices_add_preview_header"))
                                .font(.headline)
                                .foregroundColor(.black)

                            Spacer()
                        }

                        Divider()

                        if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(LocalizedStringKey("voices_add_preview_empty"))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            previewContentView
                                .foregroundColor(.black)
                        }
                    }

                    if !selectedPostImages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("voices_add_images_header"))
                                .font(.headline)
                                .foregroundColor(.black)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(selectedPostImages) { item in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: item.image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                            HStack(spacing: 6) {
                                                Button {
                                                    previewingPostImage = item
                                                } label: {
                                                    Image("Icon_Image_View")
                                                        .resizable()
                                                        .renderingMode(.template)
                                                        .scaledToFit()
                                                        .frame(width: 14, height: 14)
                                                        .padding(6)
                                                        .foregroundColor(.white)
                                                        .background(Color.black.opacity(0.65))
                                                        .clipShape(Circle())
                                                }

                                                Button {
                                                    removeSelectedPhoto(id: item.id)
                                                } label: {
                                                    Image(systemName: "trash.fill")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .frame(width: 26, height: 26)
                                                        .background(Color.black.opacity(0.65))
                                                        .clipShape(Circle())
                                                }
                                            }
                                            .padding(6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }
                    .padding(24)
                    .padding(.bottom, 100)
                }
            }
            .safeAreaInset(edge: .bottom) {
                publishButton
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(.systemBackground))
            }
            .navigationTitle(LocalizedStringKey("voices_add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
            .sheet(isPresented: $isShowingLinkSheet) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("Texto del enlace", text: $linkTitleInput)
                            TextField("https://ejemplo.com", text: $linkURLInput)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        } header: {
                            Text("Insertar enlace")
                        }
                    }
                    .navigationTitle("Agregar URL")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") {
                                isShowingLinkSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Agregar") {
                                applyLinkFromSheet()
                            }
                            .disabled(linkURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(item: $previewingPostImage) { item in
                NavigationStack {
                    Color.black
                        .ignoresSafeArea()
                        .overlay {
                            Image(uiImage: item.image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(LocalizedStringKey("cancel")) {
                                    previewingPostImage = nil
                                }
                                .foregroundColor(.white)
                            }
                        }
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    await loadSelectedPhotos(from: newItems)
                }
            }
            .alert("No se pudo publicar", isPresented: Binding(
                get: { publishErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        publishErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    publishErrorMessage = nil
                }
            } message: {
                Text(publishErrorMessage ?? "")
            }
        }
    }
}

private struct MarkdownEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    var onAutoListInsertion: (String, Int) -> Void
    var onAutoListExit: (NSRange) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        let safeLocation = min(max(selectedRange.location, 0), uiView.text.count)
        let safeLength = min(max(selectedRange.length, 0), uiView.text.count - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)

        if uiView.selectedRange != safeRange {
            uiView.selectedRange = safeRange
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: MarkdownEditorTextView

        init(_ parent: MarkdownEditorTextView) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement == "\n" else {
                return true
            }

            let nsText = textView.text as NSString
            let safeLocation = min(max(range.location, 0), nsText.length)
            let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
            let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)

            if lineText == "-" || lineText == "*" || lineText.range(of: #"^\d+\.$"#, options: .regularExpression) != nil {
                parent.onAutoListExit(lineRange)
                return false
            }

            if lineText.hasPrefix("- ") || lineText.hasPrefix("* ") {
                let marker = lineText.hasPrefix("* ") ? "* " : "- "
                parent.onAutoListInsertion(marker, safeLocation)
                return false
            }

            if let match = lineText.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                let prefix = String(lineText[match]).replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
                if let currentNumber = Int(prefix) {
                    parent.onAutoListInsertion("\(currentNumber + 1). ", safeLocation)
                    return false
                }
            }

            return true
        }


        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}

#Preview {
    ContentView()
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

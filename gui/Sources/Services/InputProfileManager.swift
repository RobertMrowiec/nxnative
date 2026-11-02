import Foundation
import Combine
import AppKit

public final class InputProfileManager: ObservableObject {
    public static let shared = InputProfileManager()

    private enum StorageKeys {
        static let activeProfileId = "NXNative_ActiveControllerProfileId"
        static let playerProfileIds = "NXNative_PlayerProfileIds"
        static let activePlayerIndex = "NXNative_ActivePlayerIndex"
    }

    @Published public var profiles: [ControllerProfile] = []
    @Published public var activePlayerIndex: Int = 0 {
        didSet {
            UserDefaults.standard.set(activePlayerIndex, forKey: StorageKeys.activePlayerIndex)
        }
    }
    @Published public var playerProfileIds: [Int: UUID] = [:] {
        didSet {
            persistPlayerProfileIds()
            exportActiveMappingToDisk()
        }
    }
    @Published public var activeProfileId: UUID = UUID() {
        didSet {
            UserDefaults.standard.set(activeProfileId.uuidString, forKey: StorageKeys.activeProfileId)
            playerProfileIds[activePlayerIndex] = activeProfileId
            exportActiveMappingToDisk()
        }
    }
    @Published public var listeningTarget: KeyBindingTarget? = nil
    public var listeningStartTime: TimeInterval = 0

    public func startListening(for target: KeyBindingTarget) {
        listeningStartTime = ProcessInfo.processInfo.systemUptime
        listeningTarget = target
    }

    internal let fileManager = FileManager.default

    internal var profilesDirectory: URL {
        let appSup = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSup.appendingPathComponent("nxnative/controller_profiles", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public var globalMappingFile: URL {
        let appSup = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSup.appendingPathComponent("nxnative", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("input_mapping.json")
    }

    private init() {
        loadProfiles()
        setupLifecyclePersistence()
    }

    private func setupLifecyclePersistence() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushAllSettings()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushAllSettings()
        }
    }

    public func flushAllSettings() {
        saveProfileToDisk(activeProfile)
        UserDefaults.standard.set(activeProfileId.uuidString, forKey: StorageKeys.activeProfileId)
        UserDefaults.standard.synchronize()
        exportActiveMappingToDisk()
    }

    public var activeProfile: ControllerProfile {
        if let found = profiles.first(where: { $0.id == activeProfileId }) {
            return found
        }
        return profiles.first ?? ControllerProfile.nintendoDefault
    }

    public func profile(forPlayer playerIndex: Int) -> ControllerProfile {
        if let pid = playerProfileIds[playerIndex],
           let found = profiles.first(where: { $0.id == pid }) {
            return found
        }
        return activeProfile
    }

    public func setProfile(_ profile: ControllerProfile, forPlayer playerIndex: Int) {
        playerProfileIds[playerIndex] = profile.id
        if activePlayerIndex == playerIndex {
            activeProfileId = profile.id
        } else {
            exportActiveMappingToDisk()
        }
    }

    private func persistPlayerProfileIds() {
        let strDict = playerProfileIds.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value.uuidString }
        UserDefaults.standard.set(strDict, forKey: StorageKeys.playerProfileIds)
    }

    private func restorePlayerProfileIds() {
        if let strDict = UserDefaults.standard.dictionary(forKey: StorageKeys.playerProfileIds) as? [String: String] {
            let restored = strDict.compactMap { (k, v) -> (Int, UUID)? in
                guard let pIdx = Int(k), let uuid = UUID(uuidString: v), profiles.contains(where: { $0.id == uuid }) else { return nil }
                return (pIdx, uuid)
            }
            self.playerProfileIds = Dictionary(uniqueKeysWithValues: restored)
        }
        let savedPIdx = UserDefaults.standard.integer(forKey: StorageKeys.activePlayerIndex)
        if savedPIdx >= 0 && savedPIdx < 8 {
            self.activePlayerIndex = savedPIdx
        }
    }

    public func loadProfiles() {
        let dir = profilesDirectory
        var loaded: [ControllerProfile] = []

        if let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension.lowercased() == "json" {
                if let data = try? Data(contentsOf: file),
                   let prof = try? JSONDecoder().decode(ControllerProfile.self, from: data) {
                    loaded.append(prof)
                }
            }
        }

        if loaded.isEmpty {
            let nintendo = ControllerProfile.nintendoDefault
            let xbox = ControllerProfile.xboxLayout
            let ps = ControllerProfile.playstationLayout
            loaded = [nintendo, xbox, ps]
            for p in loaded {
                saveProfileToDisk(p)
            }
        }

        for i in 0..<loaded.count {
            if loaded[i].mouseSensitivity == 1.0 {
                loaded[i].mouseSensitivity = 5.0
                saveProfileToDisk(loaded[i])
            }
        }

        self.profiles = loaded

        if let savedIdStr = UserDefaults.standard.string(forKey: StorageKeys.activeProfileId),
           let uuid = UUID(uuidString: savedIdStr),
           loaded.contains(where: { $0.id == uuid }) {
            self.activeProfileId = uuid
        } else {
            self.activeProfileId = loaded.first?.id ?? UUID()
        }

        restorePlayerProfileIds()
        if let currentPId = playerProfileIds[activePlayerIndex], loaded.contains(where: { $0.id == currentPId }) {
            self.activeProfileId = currentPId
        } else {
            self.playerProfileIds[activePlayerIndex] = self.activeProfileId
        }

        // Unify custom keyboard/mouse bindings across all profiles so Shift, Space, and Mouse 1 work everywhere by default
        let defaultKB = ControllerProfile.nintendoDefault.keyboardBindings
        if let customizedSource = profiles.first(where: { $0.id == activeProfileId && $0.keyboardBindings != defaultKB })
            ?? profiles.first(where: { $0.keyboardBindings != defaultKB }) {
            syncKeyboardSettingsAcrossAllProfiles(from: customizedSource)
        } else {
            exportActiveMappingToDisk()
        }
    }

    public func updateProfile(_ profile: ControllerProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            let old = profiles[idx]
            let keyboardOrMouseChanged =
                old.keyboardBindings != profile.keyboardBindings ||
                old.keyboardMovement != profile.keyboardMovement ||
                old.mouseAsRightStick != profile.mouseAsRightStick ||
                old.mouseSensitivity != profile.mouseSensitivity ||
                old.mouseInvertX != profile.mouseInvertX ||
                old.mouseInvertY != profile.mouseInvertY ||
                old.mouseRightStickMode != profile.mouseRightStickMode

            profiles[idx] = profile
            saveProfileToDisk(profile)

            if keyboardOrMouseChanged {
                syncKeyboardSettingsAcrossAllProfiles(from: profile)
            } else {
                exportActiveMappingToDisk()
            }
        }
    }

    public func bindCapturedInput(keyCode: UInt16) {
        guard let target = listeningTarget else { return }
        var current = activeProfile
        // A key has one job: free it from any button or movement direction before reassigning.
        current.keyboardBindings = current.keyboardBindings.filter { $0.key != keyCode }
        current.keyboardMovement = current.keyboardMovement.filter { $0.value != keyCode }
        switch target {
        case .switchButton(let btn):
            current.keyboardBindings = current.keyboardBindings.filter { $0.value != btn }
            current.keyboardBindings[keyCode] = btn
        case .movement(let dir):
            current.keyboardMovement[dir] = keyCode
        }
        listeningTarget = nil
        updateProfile(current)
        SoundEffectService.shared.play(.click)
    }

    public func cancelListening() {
        if listeningTarget != nil {
            listeningTarget = nil
            SoundEffectService.shared.play(.click)
        }
    }

    public func createProfile(name: String, basedOn source: ControllerProfile? = nil) -> ControllerProfile {
        let base = source ?? activeProfile
        let newProfile = ControllerProfile(
            name: name,
            isDefault: false,
            targetDeviceName: base.targetDeviceName,
            gamepadBindings: base.gamepadBindings,
            keyboardBindings: base.keyboardBindings,
            keyboardMovement: base.keyboardMovement,
            analogDeadzone: base.analogDeadzone,
            mouseAsRightStick: base.mouseAsRightStick,
            mouseSensitivity: base.mouseSensitivity,
            mouseInvertX: base.mouseInvertX,
            mouseInvertY: base.mouseInvertY,
            mouseRightStickMode: base.mouseRightStickMode
        )
        profiles.append(newProfile)
        saveProfileToDisk(newProfile)
        activeProfileId = newProfile.id
        return newProfile
    }

    public func duplicateProfile(_ profile: ControllerProfile) -> ControllerProfile {
        createProfile(name: "\(profile.name) (Copy)", basedOn: profile)
    }

    public func deleteProfile(_ profile: ControllerProfile) {
        guard !profile.isDefault && profiles.count > 1 else { return }
        profiles.removeAll(where: { $0.id == profile.id })
        let file = profilesDirectory.appendingPathComponent("\(profile.id.uuidString).json")
        try? fileManager.removeItem(at: file)

        if activeProfileId == profile.id {
            activeProfileId = profiles.first?.id ?? UUID()
        }
    }

    public func resetActiveProfileToDefault() {
        let def = ControllerProfile.nintendoDefault
        var current = activeProfile
        current.gamepadBindings = def.gamepadBindings
        current.keyboardBindings = def.keyboardBindings
        current.keyboardMovement = def.keyboardMovement
        current.analogDeadzone = def.analogDeadzone
        current.mouseAsRightStick = def.mouseAsRightStick
        current.mouseSensitivity = def.mouseSensitivity
        current.mouseInvertX = def.mouseInvertX
        current.mouseInvertY = def.mouseInvertY
        current.mouseRightStickMode = def.mouseRightStickMode
        updateProfile(current)
    }

    public func saveProfileToDisk(_ profile: ControllerProfile) {
        let file = profilesDirectory.appendingPathComponent("\(profile.id.uuidString).json")
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: file, options: [.atomic])
        }
        UserDefaults.standard.synchronize()
    }
}

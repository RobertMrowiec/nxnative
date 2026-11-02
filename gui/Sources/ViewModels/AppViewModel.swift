import Foundation
import SwiftUI
import AppKit

public final class AppViewModel: ObservableObject, BuildRunnerDelegate, InstallerServiceDelegate, UpdateCheckerDelegate {
    // MARK: - Storage Keys for Persistence
    public enum StorageKeys {
        public static let savedGameFolder = "NXNative_SavedGameFolder"
        public static let savedGameFolders = "NXNative_SavedGameFolders"
        public static let savedLibraryFolder = "NXNative_SavedLibraryFolder"
        public static let savedCustomOutputFolder = "NXNative_SavedCustomOutputFolder"
        public static let savedUseCustomOutput = "NXNative_SavedUseCustomOutput"
        public static let savedProdKeysPath = "NXNative_SavedProdKeysPath"
        public static let savedShowFps = "NXNative_SavedShowFps"
        public static let savedKeepExtracted = "NXNative_SavedKeepExtracted"
        public static let savedPlatform = "NXNative_SavedPlatform"
        public static let savedIconAppearanceMode = "NXNative_SavedIconAppearanceMode_v2"
        public static let savedHighlightTheme = "NXNative_SavedHighlightTheme"
        public static let savedLiquidGlassEnabled = "NXNative_SavedLiquidGlassEnabled"
        public static let savedLiquidGlassAppearance = "NXNative_SavedLiquidGlassAppearance"
        public static let savedLiquidGlassIntensity = "NXNative_SavedLiquidGlassIntensity"
        public static let savedCompatibilityDisplayMode = "NXNative_SavedCompatibilityDisplayMode"
        public static let savedLibraryCardSize = "NXNative_SavedLibraryCardSize"
        public static let savedLibraryCardScale = "NXNative_SavedLibraryCardScale"
        public static let savedLauncherLanguage = "NXNative_SavedLauncherLanguage"
        public static let savedHiddenGamePaths = "NXNative_SavedHiddenGamePaths"
        public static let savedRomfsSeparate = "NXNative_SavedRomfsSeparate"
        public static let savedAutoRomfsSplitLimitGB = "NXNative_SavedAutoRomfsSplitLimitGB"
        public static let savedCustomCertP12Path = "NXNative_SavedCustomCertP12Path"
        public static let savedCustomCertPassword = "NXNative_SavedCustomCertPassword"
        public static let savedCustomProvisioningProfilePath = "NXNative_SavedCustomProvisioningProfilePath"
        public static let savedMenuBarIconStyle = "NXNative_SavedMenuBarIconStyle"
        public static let savedAllowOtherMetal = "NXNative_SavedAllowOtherMetal"
        public static let savedDeveloperMode = "NXNative_SavedDeveloperMode"
        public static let savedNonSwitchAppPaths = "NXNative_SavedNonSwitchAppPaths"
        public static let savedNonSwitchGameFolders = "NXNative_SavedNonSwitchGameFolders"
        public static let savedLastPlayedDates = "NXNative_SavedLastPlayedDates"
        public static let savedActiveGroupFilter = "NXNative_SavedActiveGroupFilter"
        public static let savedActiveSortOption = "NXNative_SavedActiveSortOption"
    }
    
    // MARK: - Workspace & Paths
    @Published public var defaultInstallPath: String = ""
    @Published public var nxnativePath: String = ""
    @Published public var isNxnativeValid: Bool = false
    @Published public var isCloningRepository: Bool = false
    @Published public var cloneErrorMessage: String? = nil
    @Published public var enginePatches: [EnginePatchItem] = []
    @Published public var showCltInstallAlert: Bool = false
    
    // MARK: - Keys
    @Published public var prodKeysPath: String = "" {
        didSet {
            if !prodKeysPath.isEmpty {
                UserDefaults.standard.set(prodKeysPath, forKey: StorageKeys.savedProdKeysPath)
            }
        }
    }
    @Published public var prodKeysSource: String = ""
    @Published public var isProdKeysValid: Bool = false
    
    // MARK: - Game Selection
    @Published public var selectedGameFolder: URL? {
        didSet {
            if let folder = selectedGameFolder {
                UserDefaults.standard.set(folder.path, forKey: StorageKeys.savedGameFolder)
                addGameFolder(folder)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.savedGameFolder)
            }
        }
    }
    @Published public var gameFolders: [URL] = [] {
        didSet {
            let paths = gameFolders.map { $0.path }
            UserDefaults.standard.set(paths, forKey: StorageKeys.savedGameFolders)
        }
    }
    @Published public var detectedFiles: [GameFileItem] = []
    @Published public var detectedGames: [SelectableGame] = []
    @Published public var selectedGame: SelectableGame? = nil {
        didSet {
            if let game = selectedGame {
                self.appName = game.name
                self.userDidManuallyOverrideRomfsSeparate = false
                self.evaluateAutoRomfsSplit()
            }
        }
    }
    
    // MARK: - Port Modal & Auto Deployment
    @Published public var gameForPortModal: SelectableGame? = nil
    @Published public var autoDeployToDeviceOnFinish: Bool = false
    @Published public var buildingGameId: String? = nil
    
    public func isGameAlreadyPorted(_ selectable: SelectableGame) -> Bool {
        let cleanSelectable = GameScanner.shared.cleanGameTitle(selectable.name).lowercased()
        return libraryGames.contains { ported in
            if let selTid = selectable.titleId, !selTid.isEmpty,
               let portTid = ported.titleId, !portTid.isEmpty,
               selTid.caseInsensitiveCompare(portTid) == .orderedSame {
                return true
            }
            let cleanPorted = GameScanner.shared.cleanGameTitle(ported.name).lowercased()
            return cleanSelectable == cleanPorted
        }
    }
    
    public var unportedGames: [SelectableGame] {
        detectedGames.filter { !isGameAlreadyPorted($0) }
    }
    
    // MARK: - Drag & Drop & ZIP
    @Published public var isExtractingZip: Bool = false
    @Published public var zipExtractionMessage: String = ""
    @Published public var dropErrorMessage: String? = nil
    
    // MARK: - Target & Output
    @Published public var platform: TargetPlatform = .macApp {
        didSet {
            UserDefaults.standard.set(platform.rawValue, forKey: StorageKeys.savedPlatform)
            evaluateAutoRomfsSplit()
            if isKeepExtractedLocked {
                keepExtracted = true
            }
        }
    }
    @Published public var useCustomOutputFolder: Bool = false {
        didSet {
            UserDefaults.standard.set(useCustomOutputFolder, forKey: StorageKeys.savedUseCustomOutput)
        }
    }
    @Published public var customOutputFolder: URL? {
        didSet {
            if let folder = customOutputFolder {
                UserDefaults.standard.set(folder.path, forKey: StorageKeys.savedCustomOutputFolder)
            } else {
                UserDefaults.standard.removeObject(forKey: StorageKeys.savedCustomOutputFolder)
            }
        }
    }
    
    // MARK: - Library State & Card Scale Slider
    @Published public var libraryGames: [PortedGame] = []
    @Published public var libraryFolder: URL? {
        didSet {
            if let folder = libraryFolder {
                UserDefaults.standard.set(folder.path, forKey: StorageKeys.savedLibraryFolder)
            }
        }
    }
    @Published public var librarySearchText: String = ""
    @Published public var isScanningLibrary: Bool = false
    @Published public var libraryCardSize: LibraryCardSize = .regular {
        didSet {
            UserDefaults.standard.set(libraryCardSize.rawValue, forKey: StorageKeys.savedLibraryCardSize)
        }
    }
    @Published public var libraryCardScale: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(libraryCardScale, forKey: StorageKeys.savedLibraryCardScale)
        }
    }
    @Published public var draggedGame: PortedGame? = nil
    @Published public var draggedItemPath: String? = nil
    @Published public var isTextInputActive: Bool = false
    @Published public var gameForSettingsSheet: PortedGame? = nil {
        didSet {
            if let game = gameForSettingsSheet {
                activeSettingsConfig = GameRuntimeConfig.load(for: game)
                settingsModalFocusIndex = 0
            }
        }
    }
    @Published public var activeSettingsConfig: GameRuntimeConfig = GameRuntimeConfig()
    internal var runtimeConfigCache: [String: GameRuntimeConfig] = [:]
    @Published public var settingsModalFocusIndex: Int = 0
    @Published public var controlsFocusIndex: Int = 0
    @Published public var settingsFocusIndex: Int = 0
    
    // Controls Tab Navigation (2-Level Card Architecture)
    @Published public var controlsCardIndex: Int = 0 // 0: Header, 1: Mapping, 2: Deadzone, 3: Rumble, 4: Mouse
    @Published public var isInsideControlsCard: Bool = false
    @Published public var controlsHeaderFocus: Int = 0 // 0: Player, 1: Profile, 2: Duplicate, 3: Reset
    @Published public var controlsMappingFocus: Int = 0 // 0..18 (Buttons + Swap AB/XY)
    @Published public var controlsHapticsFocus: Int = 0 // 0: Master, 1: Strength, 2: Floor Boost, 3: Test
    @Published public var controlsMouseFocus: Int = 0 // 0: Master, 1: Sensitivity, 2: InvertX, 3: InvertY, 4: Mode
    @Published public var showControlsPlayerModal: Bool = false
    @Published public var showControlsProfileModal: Bool = false
    @Published public var controlsPlayerModalFocus: Int = 0
    @Published public var controlsProfileModalFocus: Int = 0
    @Published public var controlsListeningButton: SwitchButton? = nil

    // Personalize Tab Navigation (2-Level Card Architecture)
    @Published public var personalizeCardIndex: Int = 1 // 0: Reset, 1: Language, 2: Colors/Glass, 3: Icons, 4: Sound
    @Published public var isInsidePersonalizeCard: Bool = false
    @Published public var personalizeLangFocus: Int = 0
    @Published public var personalizeColorFocus: Int = 0 // 0..7: Swatches, 8: Glass Slider, 9: Glass Toggle
    @Published public var personalizeIconFocus: Int = 0 // AppIconAppearanceMode index
    @Published public var personalizeMenuBarFocus: Int = 0 // MenuBarIconStyle index
    @Published public var gameToDelete: PortedGame? = nil
    @Published public var showDeleteConfirm: Bool = false
    @Published public var hiddenGamePaths: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(hiddenGamePaths), forKey: StorageKeys.savedHiddenGamePaths)
        }
    }
    @Published public var gameToRemove: PortedGame? = nil
    @Published public var showRemoveConfirm: Bool = false
    @Published public var gameToTrash: PortedGame? = nil
    @Published public var showTrashConfirm: Bool = false
    
    // MARK: - Non-Switch Games & Filtering & Sorting
    @Published public var savedNonSwitchAppPaths: [String] = [] {
        didSet {
            UserDefaults.standard.set(savedNonSwitchAppPaths, forKey: StorageKeys.savedNonSwitchAppPaths)
            refreshLibrary()
        }
    }
    @Published public var nonSwitchGameFolders: [URL] = [] {
        didSet {
            let paths = nonSwitchGameFolders.map { $0.path }
            UserDefaults.standard.set(paths, forKey: StorageKeys.savedNonSwitchGameFolders)
            refreshLibrary()
        }
    }
    @Published public var lastPlayedTimestamps: [String: Double] = [:] {
        didSet {
            UserDefaults.standard.set(lastPlayedTimestamps, forKey: StorageKeys.savedLastPlayedDates)
        }
    }
    @Published public var activeGroupFilter: LibraryGroupFilter = .categories {
        didSet {
            UserDefaults.standard.set(activeGroupFilter.rawValue, forKey: StorageKeys.savedActiveGroupFilter)
        }
    }
    @Published public var activeSortOption: LibrarySortOption = .lastPlayed {
        didSet {
            UserDefaults.standard.set(activeSortOption.rawValue, forKey: StorageKeys.savedActiveSortOption)
            applyActiveSorting()
        }
    }
    
    public func recordLastPlayed(for game: PortedGame) {
        let key = game.uniqueKey
        let now = Date().timeIntervalSince1970
        var dict = lastPlayedTimestamps
        dict[key] = now
        lastPlayedTimestamps = dict
    }
    
    public func lastPlayedDate(for game: PortedGame) -> Date? {
        if let ts = lastPlayedTimestamps[game.uniqueKey] {
            return Date(timeIntervalSince1970: ts)
        }
        return nil
    }
    
    public func addNonSwitchGame(url: URL) {
        let path = url.standardized.path
        guard FileManager.default.fileExists(atPath: path), url.pathExtension.lowercased() == "app" else { return }
        if !savedNonSwitchAppPaths.contains(path) {
            var paths = savedNonSwitchAppPaths
            paths.append(path)
            savedNonSwitchAppPaths = paths
        }
    }
    
    public func removeNonSwitchGame(path: String) {
        savedNonSwitchAppPaths.removeAll { $0 == path }
    }
    
    // MARK: - Compatibility Database
    @Published public var compatibleGames: [CompatibleGameItem] = []
    @Published public var isLoadingCompatibility: Bool = false
    @Published public var compatibilityFilter: String = "All"
    @Published public var compatibilityRamFilter: Int? = nil
    @Published public var compatibilityChipFilter: IphoneChipTier? = nil
    @Published public var compatibilityNameFilter: String = "All"
    @Published public var compatibilitySearchText: String = ""
    @Published public var compatibilityLastUpdated: Date? = nil
    @Published public var isCompatibilityFromOnline: Bool = false
    @Published public var compatibilityDisplayMode: CompatibilityDisplayMode = .list {
        didSet {
            UserDefaults.standard.set(compatibilityDisplayMode.rawValue, forKey: StorageKeys.savedCompatibilityDisplayMode)
        }
    }
    @Published public var compatibilityFocusArea: CompatibilityFocusArea = .filters
    @Published public var focusedCompatibilityIndex: Int = 0
    @Published public var focusedCompatibilityButtonIndex: CompatibilityButtonFocus = .notes
    @Published public var compatibilityGridColumnCount: Int = 6
    
    // MARK: - System Prerequisites & Installer
    @Published public var prerequisites: SystemPrerequisites = SystemPrerequisites()
    @Published public var isCheckingPrerequisites: Bool = false
    @Published public var isInstallingDependency: Bool = false
    @Published public var installerCurrentItem: String? = nil
    @Published public var installerLogs: [String] = []
    @Published public var showInstallerSheet: Bool = false
    @Published public var dependencyToUninstall: DependencyStatus? = nil
    @Published public var showUninstallConfirm: Bool = false
    
    // MARK: - Update Checker & About Sheet
    @Published public var showAboutSheet: Bool = false
    @Published public var showUpdateSheet: Bool = false
    @Published public var showControlsGuideSheet: Bool = false
    @Published public var isCheckingUpdate: Bool = false
    @Published public var updateInfo: UpdateInfo? = nil
    @Published public var isApplyingUpdate: Bool = false
    @Published public var updateInstallLogs: [String] = []
    @Published public var updateCompletedReadyToRelaunch: Bool = false
    @Published public var updateSuccessBanner: String? = nil
    @Published public var updateErrorBanner: String? = nil
    
    // MARK: - Advanced Options
    @Published public var appName: String = ""
    @Published public var bundleId: String = ""
    @Published public var selectedLanguage: String = "auto"
    @Published public var showFps: Bool = true {
        didSet {
            UserDefaults.standard.set(showFps, forKey: StorageKeys.savedShowFps)
        }
    }
    @Published public var keepExtracted: Bool = true {
        didSet {
            UserDefaults.standard.set(keepExtracted, forKey: StorageKeys.savedKeepExtracted)
        }
    }
    @Published public var surveyOnly: Bool = false
    @Published public var allowOtherMetal: Bool = true {
        didSet {
            UserDefaults.standard.set(allowOtherMetal, forKey: StorageKeys.savedAllowOtherMetal)
        }
    }
    @Published public var userDidManuallyOverrideRomfsSeparate: Bool = false
    @Published public var romfsSeparate: Bool = false {
        didSet {
            UserDefaults.standard.set(romfsSeparate, forKey: StorageKeys.savedRomfsSeparate)
            if romfsSeparate {
                keepExtracted = true
            }
        }
    }
    @Published public var autoRomfsSplitLimitGB: Double = 8.0 {
        didSet {
            UserDefaults.standard.set(autoRomfsSplitLimitGB, forKey: StorageKeys.savedAutoRomfsSplitLimitGB)
            evaluateAutoRomfsSplit()
        }
    }
    @Published public var customCertP12Path: String = "" {
        didSet {
            UserDefaults.standard.set(customCertP12Path, forKey: StorageKeys.savedCustomCertP12Path)
        }
    }
    @Published public var customCertPassword: String = "" {
        didSet {
            UserDefaults.standard.set(customCertPassword, forKey: StorageKeys.savedCustomCertPassword)
        }
    }
    @Published public var customProvisioningProfilePath: String = "" {
        didSet {
            UserDefaults.standard.set(customProvisioningProfilePath, forKey: StorageKeys.savedCustomProvisioningProfilePath)
        }
    }
    
    public var shouldSuggestRomfsSplit: Bool {
        guard platform == .ios else { return false }
        let totalBytes = selectedGame?.totalSizeBytes ?? detectedFiles.reduce(0) { $0 + $1.sizeBytes }
        let limitBytes = Int64(autoRomfsSplitLimitGB * 1_073_741_824)
        return totalBytes >= limitBytes
    }
    
    public func evaluateAutoRomfsSplit() {
        guard platform == .ios else { return }
        if shouldSuggestRomfsSplit {
            if !userDidManuallyOverrideRomfsSeparate {
                romfsSeparate = true
            }
        } else {
            if !userDidManuallyOverrideRomfsSeparate {
                romfsSeparate = false
            }
        }
        if isKeepExtractedLocked {
            keepExtracted = true
        }
    }
    
    public var isRomfsSeparateAutoActive: Bool {
        platform == .ios && romfsSeparate && shouldSuggestRomfsSplit && !userDidManuallyOverrideRomfsSeparate
    }
    
    public var isKeepExtractedLocked: Bool {
        if platform == .macApp { return true }
        if platform == .ios && romfsSeparate { return true }
        return false
    }
    
    public var keepExtractedLockReason: String? {
        if platform == .macApp {
            return tr("build.opt_keep_extracted_locked_mac")
        }
        if platform == .ios && romfsSeparate {
            return tr("build.opt_keep_extracted_locked_romfs")
        }
        return nil
    }
    
    public var selectedGameSizeString: String {
        let totalBytes = selectedGame?.totalSizeBytes ?? detectedFiles.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    // MARK: - Build State
    @Published public var isBuilding: Bool = false
    @Published public var currentStageName: String = ""
    @Published public var currentStepName: String = ""
    @Published public var stageIndex: Int = 0
    @Published public var totalStages: Int = 0
    @Published public var progressFraction: Double = 0.0
    @Published public var etaSeconds: Double? = nil
    @Published public var buildStages: [BuildStageItem] = []
    @Published public var showLiveLogsInBuild: Bool = true
    @Published public var logs: [LogEntry] = []
    @Published public var buildError: String? = nil
    @Published public var buildSuccessPath: String? = nil
    @Published public var buildWizardStep: Int = 1
    @Published public var isDeveloperMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isDeveloperMode, forKey: StorageKeys.savedDeveloperMode)
            if !isDeveloperMode && selectedTab == 5 {
                selectedTab = 0
            }
        }
    }
    @Published public var iconAppearanceMode: AppIconAppearanceMode = .default {
        didSet {
            UserDefaults.standard.set(iconAppearanceMode.rawValue, forKey: StorageKeys.savedIconAppearanceMode)
            updateDockIcon()
            DispatchQueue.main.async {
                MenuBarManager.shared.updateMenuBarIcon()
            }
        }
    }
    @Published public var menuBarIconStyle: MenuBarIconStyle = .matchAppIcon {
        didSet {
            UserDefaults.standard.set(menuBarIconStyle.rawValue, forKey: StorageKeys.savedMenuBarIconStyle)
            let style = menuBarIconStyle
            DispatchQueue.main.async {
                MenuBarManager.shared.updateMenuBarIcon(style: style)
            }
        }
    }
    @Published public var highlightTheme: LauncherHighlightTheme = NXTheme.activeHighlightTheme {
        didSet {
            NXTheme.activeHighlightTheme = highlightTheme
            UserDefaults.standard.set(highlightTheme.rawValue, forKey: StorageKeys.savedHighlightTheme)
        }
    }
    @Published public var isLiquidGlassEnabled: Bool = NXTheme.isLiquidGlassEnabled {
        didSet {
            NXTheme.isLiquidGlassEnabled = isLiquidGlassEnabled
            UserDefaults.standard.set(isLiquidGlassEnabled, forKey: StorageKeys.savedLiquidGlassEnabled)
        }
    }
    @Published public var liquidGlassAppearance: LiquidGlassAppearance = NXTheme.liquidGlassAppearance {
        didSet {
            NXTheme.liquidGlassAppearance = liquidGlassAppearance
            UserDefaults.standard.set(liquidGlassAppearance.rawValue, forKey: StorageKeys.savedLiquidGlassAppearance)
        }
    }
    @Published public var liquidGlassIntensity: Double = NXTheme.liquidGlassIntensity {
        didSet {
            let clamped = min(max(liquidGlassIntensity, 0.0), 1.0)
            NXTheme.liquidGlassIntensity = clamped
            UserDefaults.standard.set(clamped, forKey: StorageKeys.savedLiquidGlassIntensity)
            let derivedMode: LiquidGlassAppearance = clamped >= 0.5 ? .liquid : .frosted
            if liquidGlassAppearance != derivedMode {
                liquidGlassAppearance = derivedMode
            }
        }
    }
    public var liquidGlassEnvironment: NXLiquidGlassEnvironment {
        NXLiquidGlassEnvironment(
            isEnabled: isLiquidGlassEnabled,
            appearance: liquidGlassAppearance,
            intensity: liquidGlassIntensity,
            highlightTheme: highlightTheme
        )
    }
    @Published public var launcherLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(launcherLanguage.rawValue, forKey: StorageKeys.savedLauncherLanguage)
            LocalizationService.shared.currentLanguage = launcherLanguage
        }
    }
    
    // MARK: - Navigation & Gamepad State
    @Published public var selectedTab: Int = 0
    @Published public var focusedGameIndex: Int = 0
    @Published public var focusedMacIndex: Int = 0
    @Published public var focusedSwitch2Index: Int = 0
    @Published public var focusedIosIndex: Int = 0
    @Published public var focusedNonSwitchIndex: Int = 0
    @Published public var focusedUnifiedIndex: Int = 0
    @Published public var unifiedGridColumnsCount: Int = 4
    @Published public var activeLibraryShelf: LibraryShelfFocus = .mac
    @Published public var focusedUnportedGameIndex: Int = 0
    @Published public var portModalFocusIndex: Int = 0
    @Published public var isPortAdvancedExpanded: Bool = false
    @Published public var showRyujinxNotFoundSheet: Bool = false
    @Published public var isFocusOnDeck: Bool = false
    @Published public var isGameActionMenuPresented: Bool = false
    @Published public var gameActionFocusedIndex: Int = 0
    @Published public var launchingGameId: UUID? = nil
    @Published public var runningGameTitle: String? = nil

    public func trimHistoricalLogs(keepCount: Int = 200) {
        if logs.count > keepCount {
            logs = Array(logs.suffix(keepCount))
        }
        if installerLogs.count > keepCount {
            installerLogs = Array(installerLogs.suffix(keepCount))
        }
        if updateInstallLogs.count > keepCount {
            updateInstallLogs = Array(updateInstallLogs.suffix(keepCount))
        }
    }
    
    public var availableLanguages: [(code: String, label: String)] {
        Self.availableLanguages
    }
    
    public func tr(_ key: String, _ args: CVarArg...) -> String {
        LocalizationService.shared.format(key: key, arguments: args)
    }
    
    let runner = BuildRunner()
    let installer = InstallerService.shared
    let updateChecker = UpdateCheckerService.shared
    
    public init() {
        runner.delegate = self
        installer.delegate = self
        updateChecker.delegate = self
        
        let root = SystemDetector.shared.resolveRootDirectory()
        self.defaultInstallPath = root.path
        
        if let savedLib = UserDefaults.standard.string(forKey: StorageKeys.savedLibraryFolder),
           FileManager.default.fileExists(atPath: savedLib) {
            self.libraryFolder = URL(fileURLWithPath: savedLib)
        } else {
            self.libraryFolder = root.appendingPathComponent("Games")
        }
        
        if UserDefaults.standard.object(forKey: StorageKeys.savedUseCustomOutput) != nil {
            self.useCustomOutputFolder = UserDefaults.standard.bool(forKey: StorageKeys.savedUseCustomOutput)
        }
        if let savedOut = UserDefaults.standard.string(forKey: StorageKeys.savedCustomOutputFolder),
           FileManager.default.fileExists(atPath: savedOut) {
            self.customOutputFolder = URL(fileURLWithPath: savedOut)
        }
        
        if let savedFps = UserDefaults.standard.object(forKey: StorageKeys.savedShowFps) as? Bool {
            self.showFps = savedFps
        }
        if let savedKeep = UserDefaults.standard.object(forKey: StorageKeys.savedKeepExtracted) as? Bool {
            self.keepExtracted = savedKeep
        }
        if let savedPlat = UserDefaults.standard.string(forKey: StorageKeys.savedPlatform),
           let p = TargetPlatform(rawValue: savedPlat) {
            self.platform = p
        }
        if let savedRomfs = UserDefaults.standard.object(forKey: StorageKeys.savedRomfsSeparate) as? Bool {
            self.romfsSeparate = savedRomfs
        }
        if let savedAllowMetal = UserDefaults.standard.object(forKey: StorageKeys.savedAllowOtherMetal) as? Bool {
            self.allowOtherMetal = savedAllowMetal
        }
        if let savedSplitLimit = UserDefaults.standard.object(forKey: StorageKeys.savedAutoRomfsSplitLimitGB) as? Double {
            self.autoRomfsSplitLimitGB = savedSplitLimit
        }
        if let savedP12 = UserDefaults.standard.string(forKey: StorageKeys.savedCustomCertP12Path) {
            self.customCertP12Path = savedP12
        }
        if let savedPass = UserDefaults.standard.string(forKey: StorageKeys.savedCustomCertPassword) {
            self.customCertPassword = savedPass
        }
        if let savedProfile = UserDefaults.standard.string(forKey: StorageKeys.savedCustomProvisioningProfilePath) {
            self.customProvisioningProfilePath = savedProfile
        }
        if let savedMode = UserDefaults.standard.string(forKey: StorageKeys.savedIconAppearanceMode) {
            self.iconAppearanceMode = AppIconAppearanceMode.from(saved: savedMode)
        }
        if let savedMenuStyle = UserDefaults.standard.string(forKey: StorageKeys.savedMenuBarIconStyle),
           let menuStyle = MenuBarIconStyle(rawValue: savedMenuStyle) {
            self.menuBarIconStyle = menuStyle
        }
        if let savedTheme = UserDefaults.standard.string(forKey: StorageKeys.savedHighlightTheme),
           let theme = LauncherHighlightTheme(rawValue: savedTheme) {
            NXTheme.activeHighlightTheme = theme
            self.highlightTheme = theme
        }
        if let savedGlassEnabled = UserDefaults.standard.object(forKey: StorageKeys.savedLiquidGlassEnabled) as? Bool {
            NXTheme.isLiquidGlassEnabled = savedGlassEnabled
            self.isLiquidGlassEnabled = savedGlassEnabled
        }
        if let savedGlassMode = UserDefaults.standard.string(forKey: StorageKeys.savedLiquidGlassAppearance),
           let glassMode = LiquidGlassAppearance(rawValue: savedGlassMode) {
            NXTheme.liquidGlassAppearance = glassMode
            self.liquidGlassAppearance = glassMode
        }
        if let savedIntensity = UserDefaults.standard.object(forKey: StorageKeys.savedLiquidGlassIntensity) as? Double {
            let clamped = min(max(savedIntensity, 0.0), 1.0)
            NXTheme.liquidGlassIntensity = clamped
            self.liquidGlassIntensity = clamped
        } else {
            let fallback = self.liquidGlassAppearance == .liquid ? 1.0 : 0.0
            NXTheme.liquidGlassIntensity = fallback
            self.liquidGlassIntensity = fallback
        }
        if let savedDisplay = UserDefaults.standard.string(forKey: StorageKeys.savedCompatibilityDisplayMode),
           let dispMode = CompatibilityDisplayMode(rawValue: savedDisplay) {
            self.compatibilityDisplayMode = dispMode
        }
        if let savedCardSize = UserDefaults.standard.string(forKey: StorageKeys.savedLibraryCardSize),
           let size = LibraryCardSize(rawValue: savedCardSize) {
            self.libraryCardSize = size
        }
        if let savedScale = UserDefaults.standard.object(forKey: StorageKeys.savedLibraryCardScale) as? Double {
            self.libraryCardScale = max(0.70, min(1.50, savedScale))
        }
        if let savedDev = UserDefaults.standard.object(forKey: StorageKeys.savedDeveloperMode) as? Bool {
            self.isDeveloperMode = savedDev
        }
        if let savedLang = UserDefaults.standard.string(forKey: StorageKeys.savedLauncherLanguage),
           let lang = AppLanguage(rawValue: savedLang) {
            self.launcherLanguage = lang
            LocalizationService.shared.currentLanguage = lang
        } else {
            self.launcherLanguage = .system
            LocalizationService.shared.currentLanguage = .system
        }
        
        detectEnvironment()
        
        // Load Game Folders
        if let savedFolders = UserDefaults.standard.stringArray(forKey: StorageKeys.savedGameFolders) {
            let urls = savedFolders.compactMap { path -> URL? in
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    return URL(fileURLWithPath: path)
                }
                return nil
            }
            self.gameFolders = urls
            self.selectedGameFolder = urls.first
        } else if let savedGamePath = UserDefaults.standard.string(forKey: StorageKeys.savedGameFolder) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: savedGamePath, isDirectory: &isDir), isDir.boolValue {
                let singleURL = URL(fileURLWithPath: savedGamePath)
                self.selectedGameFolder = singleURL
                self.gameFolders = [singleURL]
            }
        }
        
        // Load Non-Switch Games
        if let savedNonSwitch = UserDefaults.standard.stringArray(forKey: StorageKeys.savedNonSwitchAppPaths) {
            self.savedNonSwitchAppPaths = savedNonSwitch
        }
        
        // Load Non-Switch Game Folders
        if let savedNonSwitchFolders = UserDefaults.standard.stringArray(forKey: StorageKeys.savedNonSwitchGameFolders) {
            let urls = savedNonSwitchFolders.compactMap { path -> URL? in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: path) ? url : nil
            }
            self.nonSwitchGameFolders = urls
        }
        
        // Load Last Played Dates
        if let savedDates = UserDefaults.standard.dictionary(forKey: StorageKeys.savedLastPlayedDates) as? [String: Double] {
            self.lastPlayedTimestamps = savedDates
        }
        
        // Load Filters & Sorting
        if let savedFilter = UserDefaults.standard.string(forKey: StorageKeys.savedActiveGroupFilter),
           let filter = LibraryGroupFilter(rawValue: savedFilter) {
            self.activeGroupFilter = filter
        }
        if let savedSort = UserDefaults.standard.string(forKey: StorageKeys.savedActiveSortOption),
           let sort = LibrarySortOption(rawValue: savedSort) {
            self.activeSortOption = sort
        }
        
        if let savedHidden = UserDefaults.standard.stringArray(forKey: StorageKeys.savedHiddenGamePaths) {
            self.hiddenGamePaths = Set(savedHidden)
        }
        
        InputProfileManager.shared.exportActiveMappingToDisk(libraryFolder: self.libraryFolder)
        scanAllGameFolders()
        refreshLibrary()
        checkForUpdates()
        loadCompatibleGames()
        updateDockIcon()
        setupWindowMinimizeIconObserver()
        
        NotificationService.shared.requestAuthorization()
        setupControllerNavigation()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            MenuBarManager.shared.configure(with: self)
        }
    }
    
    // MARK: - Custom Signing Pickers
    public func selectCustomCertP12() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.prompt = "Select .p12 Certificate"
        panel.message = "Choose your custom Apple Developer Certificate (.p12)."
        if panel.runModal() == .OK, let url = panel.url {
            self.customCertP12Path = url.path
        }
    }

    public func selectCustomProvisioningProfile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.prompt = "Select .mobileprovision"
        panel.message = "Choose your custom Provisioning Profile (.mobileprovision)."
        if panel.runModal() == .OK, let url = panel.url {
            self.customProvisioningProfilePath = url.path
        }
    }
}

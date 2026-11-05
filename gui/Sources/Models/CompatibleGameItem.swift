import Foundation

/// Minimum Apple iPhone / iPad Apple Silicon tier required to run a ported game smoothly.
public enum IphoneChipTier: String, CaseIterable, Identifiable, Comparable, Hashable, Sendable {
    // A-Series (iPhone & iPad mini / standard)
    case a17Pro = "A17 Pro"
    case a18 = "A18"
    case a18Pro = "A18 Pro"
    case a19 = "A19"
    case a19Pro = "A19 Pro"
    case a20 = "A20"
    case a20Pro = "A20 Pro"

    // M-Series (iPad Pro / iPad Air / Mac)
    case m1 = "M1"
    case m1Pro = "M1 Pro"
    case m1Max = "M1 Max"
    case m1Ultra = "M1 Ultra"
    case m2 = "M2"
    case m2Pro = "M2 Pro"
    case m2Max = "M2 Max"
    case m2Ultra = "M2 Ultra"
    case m3 = "M3"
    case m3Pro = "M3 Pro"
    case m3Max = "M3 Max"
    case m3Ultra = "M3 Ultra"
    case m4 = "M4"
    case m4Pro = "M4 Pro"
    case m4Max = "M4 Max"
    case m4Ultra = "M4 Ultra"
    case m5 = "M5"
    case m5Pro = "M5 Pro"
    case m5Max = "M5 Max"
    case m5Ultra = "M5 Ultra"
    case m6 = "M6"
    case m6Pro = "M6 Pro"
    case m6Max = "M6 Max"
    case m6Ultra = "M6 Ultra"

    public var id: String { rawValue }

    public var isMSeries: Bool {
        rawValue.hasPrefix("M")
    }

    public var rank: Int {
        switch self {
        case .a17Pro: return 10
        case .a18: return 11
        case .a18Pro: return 12
        case .a19: return 13
        case .a19Pro: return 14
        case .a20: return 15
        case .a20Pro: return 16

        case .m1: return 20
        case .m1Pro: return 21
        case .m1Max: return 22
        case .m1Ultra: return 23

        case .m2: return 24
        case .m2Pro: return 25
        case .m2Max: return 26
        case .m2Ultra: return 27

        case .m3: return 28
        case .m3Pro: return 29
        case .m3Max: return 30
        case .m3Ultra: return 31

        case .m4: return 32
        case .m4Pro: return 33
        case .m4Max: return 34
        case .m4Ultra: return 35

        case .m5: return 36
        case .m5Pro: return 37
        case .m5Max: return 38
        case .m5Ultra: return 39

        case .m6: return 40
        case .m6Pro: return 41
        case .m6Max: return 42
        case .m6Ultra: return 43
        }
    }

    public var deviceSummary: String {
        switch self {
        case .a17Pro: return "iPhone 15 Pro, iPad mini 7"
        case .a18: return "iPhone 16 / 16 Plus"
        case .a18Pro: return "iPhone 16 Pro / Pro Max"
        case .a19: return "iPhone 17"
        case .a19Pro: return "iPhone 17 Pro / Pro Max"
        case .a20: return "iPhone 18"
        case .a20Pro: return "iPhone 18 Pro / Pro Max"

        case .m1: return "iPad Pro 2021, iPad Air 5, Mac M1"
        case .m1Pro: return "MacBook Pro 14\"/16\" (M1 Pro)"
        case .m1Max: return "MacBook Pro, Mac Studio (M1 Max)"
        case .m1Ultra: return "Mac Studio (M1 Ultra)"

        case .m2: return "iPad Pro 2022, iPad Air 6, Mac M2"
        case .m2Pro: return "Mac mini, MacBook Pro (M2 Pro)"
        case .m2Max: return "MacBook Pro, Mac Studio (M2 Max)"
        case .m2Ultra: return "Mac Studio, Mac Pro (M2 Ultra)"

        case .m3: return "iPad Air, MacBook Air/Pro, iMac (M3)"
        case .m3Pro: return "MacBook Pro (M3 Pro)"
        case .m3Max: return "MacBook Pro (M3 Max)"
        case .m3Ultra: return "Mac Studio (M3 Ultra)"

        case .m4: return "iPad Pro M4, Mac mini, iMac, MacBook Pro (M4)"
        case .m4Pro: return "MacBook Pro, Mac mini (M4 Pro)"
        case .m4Max: return "MacBook Pro (M4 Max)"
        case .m4Ultra: return "Mac Studio (M4 Ultra)"

        case .m5: return "Apple Silicon Next-Gen (M5)"
        case .m5Pro: return "Apple Silicon Next-Gen (M5 Pro)"
        case .m5Max: return "Apple Silicon Next-Gen (M5 Max)"
        case .m5Ultra: return "Apple Silicon Next-Gen (M5 Ultra)"

        case .m6: return "Apple Silicon Next-Gen (M6)"
        case .m6Pro: return "Apple Silicon Next-Gen (M6 Pro)"
        case .m6Max: return "Apple Silicon Next-Gen (M6 Max)"
        case .m6Ultra: return "Apple Silicon Next-Gen (M6 Ultra)"
        }
    }

    public static func < (lhs: IphoneChipTier, rhs: IphoneChipTier) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct CompatibleGameItem: Identifiable, Hashable {
    public var id: String { titleId }
    public let title: String
    public let titleId: String
    public let versionTested: String
    public let sdk: String
    public let engine: String
    public let graphicsApi: String
    public let readmeRelPath: String
    public let macReq: String
    public let iosReq: String
    public let storageReq: String
    public let minRamGB: Int
    public let minChipTier: IphoneChipTier
    public var isNew: Bool
    public let addedTimestamp: TimeInterval

    public var isSwitch2: Bool {
        titleId.uppercased().hasPrefix("0400")
    }

    public var isSwitch1: Bool {
        !isSwitch2
    }
    
    public init(
        title: String,
        titleId: String,
        versionTested: String,
        sdk: String,
        engine: String,
        graphicsApi: String,
        readmeRelPath: String,
        macReq: String = "Mac: 8GB RAM",
        iosReq: String = "iPhone: A16+ (6GB)",
        storageReq: String = "HD: ~6 GB",
        minRamGB: Int = 8,
        minChipTier: IphoneChipTier = .a17Pro,
        isNew: Bool = false,
        addedTimestamp: TimeInterval = 0
    ) {
        self.title = title
        self.titleId = titleId
        self.versionTested = versionTested
        self.sdk = sdk
        self.engine = engine
        self.graphicsApi = graphicsApi
        self.readmeRelPath = readmeRelPath
        self.macReq = macReq
        self.iosReq = iosReq
        self.storageReq = storageReq
        self.minRamGB = minRamGB
        self.minChipTier = minChipTier
        self.isNew = isNew
        self.addedTimestamp = addedTimestamp
    }
    
    public var githubUrl: URL? {
        let base = "https://github.com/seedds/nxnative/blob/main/dm/games/"
        return URL(string: base + readmeRelPath)
    }
    
    /// Official Nintendo Switch Box Art URL (GameTDB cover art)
    public var coverArtUrl: URL? {
        nil
    }
}

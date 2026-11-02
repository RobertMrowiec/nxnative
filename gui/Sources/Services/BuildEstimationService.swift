import Foundation
import AppKit
import SwiftUI

public enum EstimateSpeedCategory {
    case cached
    case fast
    case moderate
    case heavy
    case veryHeavy
    
    public var color: Color {
        switch self {
        case .cached:
            return Color(red: 0.15, green: 0.85, blue: 0.50) // Emerald
        case .fast:
            return Color(red: 0.20, green: 0.75, blue: 0.40) // Green
        case .moderate:
            return Color(red: 0.95, green: 0.75, blue: 0.20) // Amber
        case .heavy:
            return Color(red: 0.95, green: 0.48, blue: 0.16) // Orange
        case .veryHeavy:
            return Color(red: 0.70, green: 0.35, blue: 0.95) // Purple
        }
    }
    
    public func badgeTitle(viewModel: AppViewModel) -> String {
        switch self {
        case .cached:
            return viewModel.tr("port_modal.badge_cached")
        case .fast:
            return viewModel.tr("port_modal.badge_fast")
        case .moderate:
            return viewModel.tr("port_modal.badge_moderate")
        case .heavy:
            return viewModel.tr("port_modal.badge_heavy")
        case .veryHeavy:
            return viewModel.tr("port_modal.badge_very_heavy")
        }
    }
}

public struct BuildEstimateResult {
    public let formattedRange: String
    public let isCached: Bool
    public let shaderCount: Int
    public let speedCategory: EstimateSpeedCategory
    public let chipName: String
    public let coreCount: Int
    public let explanation: String
    
    public static var empty: BuildEstimateResult {
        BuildEstimateResult(
            formattedRange: "--",
            isCached: false,
            shaderCount: 0,
            speedCategory: .fast,
            chipName: "Apple Silicon",
            coreCount: ProcessInfo.processInfo.activeProcessorCount,
            explanation: ""
        )
    }
}

public final class BuildEstimationService {
    public static let shared = BuildEstimationService()
    
    private var estimateCache: [String: BuildEstimateResult] = [:]
    private let queue = DispatchQueue(label: "org.nxnative.build_estimation", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Mac Hardware Detection
    public func getHardwareModel() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let brand = String(cString: machine).trimmingCharacters(in: .whitespacesAndNewlines)
        return brand.isEmpty ? "Apple Silicon" : brand
    }
    
    public func getCoreCount() -> Int {
        ProcessInfo.processInfo.activeProcessorCount
    }
    
    private func getChipMultiplier(chipName: String) -> Double {
        let upper = chipName.uppercased()
        if upper.contains("M4") {
            return 1.65
        } else if upper.contains("M3") {
            return 1.40
        } else if upper.contains("M2") {
            return 1.20
        } else if upper.contains("M1") {
            return 1.00
        }
        return 1.10
    }
    
    // MARK: - Estimate Calculation
    public func estimate(for game: SelectableGame, nxnativePath: String) -> BuildEstimateResult {
        let cacheKey = "\(game.id)_\(game.titleId ?? "")_\(game.totalSizeBytes)"
        if let cached = estimateCache[cacheKey] {
            return cached
        }
        
        let chipName = getHardwareModel()
        let coreCount = getCoreCount()
        let chipMultiplier = getChipMultiplier(chipName: chipName)
        
        // 1. Check if shader cache already exists
        let isCached = checkIfCached(game: game)
        
        // 2. Determine estimated or exact shader count
        let shaderCount = resolveShaderCount(game: game, nxnativePath: nxnativePath)
        
        if isCached {
            let res = BuildEstimateResult(
                formattedRange: "30s – 1 min",
                isCached: true,
                shaderCount: shaderCount,
                speedCategory: .cached,
                chipName: chipName,
                coreCount: coreCount,
                explanation: "Cache pré-compilado detectado! Criação de aplicativo quase instantânea."
            )
            estimateCache[cacheKey] = res
            return res
        }
        
        // 3. Calculate cold build duration
        // Baseline: 8-core M1 = ~90 shaders/minute
        let effectiveRate = 90.0 * (Double(coreCount) / 8.0) * chipMultiplier
        let compileMinutes = Double(shaderCount) / max(effectiveRate, 40.0)
        let extractPackMinutes = (Double(game.totalSizeBytes) / (1024.0 * 1024.0 * 1024.0)) * 0.12
        let totalEstimatedMinutes = compileMinutes + extractPackMinutes + 0.6
        
        let minMinutes = max(1, Int(totalEstimatedMinutes * 0.85))
        let maxMinutes = max(minMinutes + 1, Int(totalEstimatedMinutes * 1.20))
        
        let formattedRange: String
        let category: EstimateSpeedCategory
        
        if maxMinutes < 5 {
            formattedRange = "~2 – 5 min"
            category = .fast
        } else if maxMinutes <= 20 {
            formattedRange = "~\(minMinutes) – \(maxMinutes) min"
            category = .moderate
        } else if maxMinutes <= 60 {
            formattedRange = "~\(minMinutes) – \(maxMinutes) min"
            category = .heavy
        } else {
            let minH = minMinutes / 60
            let minRem = minMinutes % 60
            let maxH = maxMinutes / 60
            let maxRem = maxMinutes % 60
            
            let minStr = minRem > 0 ? "\(minH)h \(minRem)m" : "\(minH)h"
            let maxStr = maxRem > 0 ? "\(maxH)h \(maxRem)m" : "\(maxH)h"
            formattedRange = "~\(minStr) – \(maxStr)"
            category = .veryHeavy
        }
        
        let res = BuildEstimateResult(
            formattedRange: formattedRange,
            isCached: false,
            shaderCount: shaderCount,
            speedCategory: category,
            chipName: chipName,
            coreCount: coreCount,
            explanation: "Estimativa baseada em \(shaderCount.formatted()) shaders compilados via LLVM Metal no seu \(chipName)."
        )
        estimateCache[cacheKey] = res
        return res
    }
    
    // MARK: - Cache Detection
    private func checkIfCached(game: SelectableGame) -> Bool {
        guard let baseFile = game.baseFile else { return false }
        let isDir = (try? baseFile.url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        let gameDir = isDir ? baseFile.url : baseFile.url.deletingLastPathComponent()
        let fm = FileManager.default
        
        var buildDirsToCheck: [URL] = []
        if let tid = game.titleId, !tid.isEmpty {
            buildDirsToCheck.append(gameDir.appendingPathComponent("\(tid)_build"))
            buildDirsToCheck.append(gameDir.appendingPathComponent("\(tid.uppercased())_build"))
            buildDirsToCheck.append(gameDir.appendingPathComponent("\(tid.lowercased())_build"))
        }
        buildDirsToCheck.append(gameDir)
        
        for bDir in buildDirsToCheck {
            let cacheDir = bDir.appendingPathComponent("shader/cache")
            if fm.fileExists(atPath: cacheDir.path) {
                if let subdirs = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
                    for sub in subdirs where sub.lastPathComponent.hasPrefix("b-") {
                        if let files = try? fm.contentsOfDirectory(at: sub, includingPropertiesForKeys: nil) {
                            let metallibCount = files.lazy.filter { $0.pathExtension == "metallib" }.prefix(100).count
                            if metallibCount >= 50 {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    // MARK: - Shader Count Resolution
    private func resolveShaderCount(game: SelectableGame, nxnativePath: String) -> Int {
        // 1. Known titles / profiles with exact known counts
        if let tid = game.titleId?.uppercased() {
            switch tid {
            case "0400A3A01EE4C000": // Pokémon Pokopia
                return 131_090
            case "040074A01BF12000": // Donkey Kong Bananza
                return 22_852
            case "0100F2C0115B6000": // Zelda: Tears of the Kingdom
                return 25_120
            case "01007EF00011E000": // Zelda: Breath of the Wild
                return 22_040
            case "010074600E9C0000": // Xenoblade Chronicles 3
                return 18_500
            case "0100000000010000": // Super Mario Odyssey
                return 4_820
            case "010093801237C000": // Metroid Dread
                return 1_240
            case "01006BB00C6F0000": // Luigi's Mansion 3
                return 3_900
            case "0100A9D01C446000": // Mario Wonder
                return 3_200
            default:
                break
            }
            
            // 2. Check local profile in nxnative/dm/games/<tid>/shader_map.tsv
            if !nxnativePath.isEmpty {
                let mapPath = URL(fileURLWithPath: nxnativePath)
                    .appendingPathComponent("dm/games/\(tid)/shader_map.tsv")
                if FileManager.default.fileExists(atPath: mapPath.path),
                   let data = try? Data(contentsOf: mapPath, options: .alwaysMapped) {
                    let lines = data.split(separator: 10) // \n
                    let validLines = lines.filter { line in
                        guard let first = line.first else { return false }
                        return first != 35 // '#'
                    }.count
                    if validLines > 0 {
                        return validLines
                    }
                }
            }
        }
        
        // 3. Heuristic based on RomFS size and Switch generation
        let gb = Double(game.totalSizeBytes) / (1024.0 * 1024.0 * 1024.0)
        if game.isSwitch2 {
            return max(3_000, Int(gb * 1_600.0))
        } else {
            return max(1_200, min(25_000, Int(gb * 550.0)))
        }
    }
}

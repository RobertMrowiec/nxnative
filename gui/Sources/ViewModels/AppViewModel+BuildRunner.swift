import Foundation
import AppKit

extension AppViewModel {
    // MARK: - BuildRunner Delegates
    public func buildRunner(_ runner: BuildRunner, didProduceLog entry: LogEntry) {
        logs.append(entry)
        if logs.count > 1200 {
            logs.removeFirst(200)
        }
    }
    
    public func buildRunner(_ runner: BuildRunner, didUpdateStage stage: String, index: Int, total: Int) {
        self.currentStageName = stage
        self.stageIndex = index
        self.totalStages = total
        
        for i in 0..<buildStages.count {
            if buildStages[i].id < index && buildStages[i].isRunning {
                buildStages[i].isRunning = false
                buildStages[i].isCompleted = true
            }
        }
        
        if let existingIdx = buildStages.firstIndex(where: { $0.id == index }) {
            buildStages[existingIdx].isRunning = true
            buildStages[existingIdx].step = ""
        } else {
            buildStages.append(BuildStageItem(id: index, name: stage, isRunning: true))
        }
    }
    
    public func buildRunner(_ runner: BuildRunner, didUpdateStep step: String) {
        self.currentStepName = step
        if let idx = buildStages.firstIndex(where: { $0.id == stageIndex }) {
            buildStages[idx].step = step
        }
    }
    
    public func buildRunner(_ runner: BuildRunner, didUpdateProgress fraction: Double, doneBytes: Double?, totalBytes: Double?, etaSeconds: Double?) {
        self.progressFraction = fraction
        self.etaSeconds = etaSeconds
    }
    
    public func buildRunner(_ runner: BuildRunner, didEndStage stage: String, index: Int, ok: Bool, elapsed: Double?, summary: String?) {
        if let idx = buildStages.firstIndex(where: { $0.id == index }) {
            buildStages[idx].isRunning = false
            buildStages[idx].isCompleted = ok
            buildStages[idx].isFailed = !ok
            buildStages[idx].elapsedSeconds = elapsed
            buildStages[idx].summary = summary
        }
    }
    
    public func buildRunner(_ runner: BuildRunner, didFinishSuccess outputPath: String?) {
        self.isBuilding = false
        self.buildingGameId = nil
        self.progressFraction = 1.0
        self.currentStageName = "Build Completed!"
        for i in 0..<buildStages.count {
            buildStages[i].isRunning = false
            buildStages[i].isCompleted = true
        }
        self.buildSuccessPath = outputPath
        self.logs.append(LogEntry(level: .success, message: "Build succeeded! Output: \(outputPath ?? "Unknown")"))
        
        if let out = outputPath {
            let targetURL = URL(fileURLWithPath: out)
            GameCoverService.shared.injectCoverIntoBundle(
                at: targetURL,
                gameName: appName.isEmpty ? (selectedGame?.name ?? "Game") : appName,
                titleId: selectedGame?.titleId
            )
        }
        
        refreshLibrary()
        
        SoundEffectService.shared.play(.launch)
        NotificationService.shared.sendPortSuccessNotification(
            gameName: appName.isEmpty ? "Ported Game" : appName,
            outputPath: outputPath
        )
        
        // Auto-deploy to iOS device if requested by user in Port modal
        if self.autoDeployToDeviceOnFinish && self.platform == .ios, let out = outputPath {
            let ipaURL = URL(fileURLWithPath: out)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                DeviceDeploymentService.shared.refreshDevicesAndTeams()
                if let dev = DeviceDeploymentService.shared.selectedDevice ?? DeviceDeploymentService.shared.connectedDevices.first {
                    let team = DeviceDeploymentService.shared.selectedSigningTeam ?? DeviceDeploymentService.shared.signingTeams.first
                    DeviceDeploymentService.shared.installApp(appBundleURL: ipaURL, on: dev, team: team) { [weak self] ok, msg in
                        if ok {
                            IosDeploymentTracker.shared.recordDeployment(forGameUrl: ipaURL, deviceName: dev.name, deviceId: dev.id)
                        }
                        self?.logs.append(LogEntry(level: ok ? .success : .error, message: "[Auto-Deploy] \(msg)"))
                    }
                }
            }
        }
    }
    
    public func buildRunner(_ runner: BuildRunner, didFinishWithError error: String) {
        self.isBuilding = false
        self.buildingGameId = nil
        if let idx = buildStages.firstIndex(where: { $0.isRunning }) {
            buildStages[idx].isRunning = false
            buildStages[idx].isFailed = true
        }
        self.buildError = error
        self.logs.append(LogEntry(level: .error, message: error))
        
        SoundEffectService.shared.play(.error)
        NotificationService.shared.sendPortErrorNotification(
            gameName: appName.isEmpty ? "Game" : appName,
            error: error
        )
    }
}

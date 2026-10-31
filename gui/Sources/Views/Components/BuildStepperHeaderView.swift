import SwiftUI

public struct BuildStepperHeaderView: View {
    @ObservedObject public var viewModel: AppViewModel
    @Namespace private var stepperNamespace
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private struct StepDescriptor {
        let step: Int
        let titleKey: String
        let iconName: String
    }
    
    private let steps: [StepDescriptor] = [
        StepDescriptor(step: 1, titleKey: "build.step_1_gamer", iconName: "gamecontroller.fill"),
        StepDescriptor(step: 2, titleKey: "build.step_2_gamer", iconName: "macbook.and.iphone"),
        StepDescriptor(step: 3, titleKey: "build.step_3_gamer", iconName: "play.circle.fill")
    ]
    
    public var body: some View {
        GlassCard(padding: 6) {
            HStack(spacing: 6) {
                ForEach(steps, id: \.step) { item in
                    stepPill(item)
                    if item.step < steps.count {
                        stepConnector(isCompleted: viewModel.buildWizardStep > item.step)
                    }
                }
            }
        }
    }
    
    private func stepPill(_ item: StepDescriptor) -> some View {
        let isCurrent = viewModel.buildWizardStep == item.step
        let isCompleted = viewModel.buildWizardStep > item.step
        let isUnlocked = (item.step < viewModel.buildWizardStep && !viewModel.isBuilding) ||
                         (item.step == 2 && viewModel.selectedGame != nil && !viewModel.isBuilding) ||
                         (item.step == 1 && !viewModel.isBuilding)
        
        return Button(action: {
            guard isUnlocked && viewModel.buildWizardStep != item.step else { return }
            SoundEffectService.shared.play(.click)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                viewModel.goToWizardStep(item.step)
            }
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            isCurrent
                                ? NXTheme.primary
                                : (isCompleted ? Color(red: 0.13, green: 0.77, blue: 0.37) : Color.white.opacity(0.12))
                        )
                        .frame(width: 22, height: 22)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: item.iconName)
                            .font(.system(size: 10, weight: isCurrent ? .bold : .semibold))
                            .foregroundColor(isCurrent ? .white : NXTheme.textSecondary)
                    }
                }
                
                Text(viewModel.tr(item.titleKey))
                    .font(.system(size: 12, weight: isCurrent ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isCurrent ? .white : (isUnlocked ? NXTheme.textPrimary.opacity(0.85) : NXTheme.textMuted))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isCurrent {
                    Capsule()
                        .fill(NXTheme.primary.opacity(0.22))
                        .overlay(
                            Capsule()
                                .strokeBorder(NXTheme.primary.opacity(0.55), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "activePill", in: stepperNamespace)
                } else if isCompleted {
                    Capsule()
                        .fill(Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.12))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(NXPressableButtonStyle())
        .disabled(!isUnlocked)
        .nxNoFocusRing()
    }
    
    private func stepConnector(isCompleted: Bool) -> some View {
        Rectangle()
            .fill(isCompleted ? Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.65) : Color.white.opacity(0.12))
            .frame(height: 2)
            .frame(minWidth: 16, maxWidth: 36)
    }
}

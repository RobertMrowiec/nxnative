import SwiftUI

public struct IosRenewalBadgeView: View {
    public let record: IosDeploymentRecord
    
    public init(record: IosDeploymentRecord) {
        self.record = record
    }
    
    private var tooltipText: String {
        if record.isExpired {
            return L10n.t("settings.ios_expired_tooltip")
        } else if record.daysRemaining == 1 {
            return L10n.t("settings.ios_critical_tooltip")
        } else if record.daysRemaining <= 3 {
            return L10n.t("settings.ios_warning_tooltip", record.daysRemaining)
        } else {
            return L10n.t("settings.ios_safe_tooltip", record.daysRemaining)
        }
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: record.isExpired ? "exclamationmark.triangle.fill" : "clock.arrow.circlepath")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(record.tier.tintColor)
            
            Text(record.badgeText)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.65))
                .overlay(
                    Capsule()
                        .strokeBorder(record.tier.tintColor.opacity(0.85), lineWidth: 1.2)
                )
                .shadow(color: record.tier.accentGlow, radius: 4, x: 0, y: 1)
        )
        .help(tooltipText)
    }
}

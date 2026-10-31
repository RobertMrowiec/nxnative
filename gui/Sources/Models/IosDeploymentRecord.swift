import Foundation
import SwiftUI

public enum RenewalTier: String, Codable, CaseIterable {
    case safe       // 4 to 7 days
    case warning    // 2 to 3 days
    case critical   // 1 day
    case expired    // <= 0 days
    
    public var tintColor: Color {
        switch self {
        case .safe:
            return Color(red: 0.13, green: 0.77, blue: 0.37) // Emerald green
        case .warning:
            return Color(red: 0.96, green: 0.62, blue: 0.04) // Amber / warm gold
        case .critical:
            return Color(red: 0.94, green: 0.27, blue: 0.27) // Coral red
        case .expired:
            return Color(red: 0.86, green: 0.15, blue: 0.15) // Deep crimson red
        }
    }
    
    public var accentGlow: Color {
        switch self {
        case .safe:
            return Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.4)
        case .warning:
            return Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.4)
        case .critical:
            return Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.45)
        case .expired:
            return Color(red: 0.86, green: 0.15, blue: 0.15).opacity(0.5)
        }
    }
}

public struct IosDeploymentRecord: Codable, Equatable {
    public var firstDeployedDate: Date
    public var lastDeployedDate: Date
    public var targetDeviceName: String?
    public var targetDeviceId: String?
    public var validityDays: Int // Default 7 days for free Apple ID sideloading
    
    public init(
        firstDeployedDate: Date = Date(),
        lastDeployedDate: Date = Date(),
        targetDeviceName: String? = nil,
        targetDeviceId: String? = nil,
        validityDays: Int = 7
    ) {
        self.firstDeployedDate = firstDeployedDate
        self.lastDeployedDate = lastDeployedDate
        self.targetDeviceName = targetDeviceName
        self.targetDeviceId = targetDeviceId
        self.validityDays = validityDays > 0 ? validityDays : 7
    }
    
    public var expirationDate: Date {
        Calendar.current.date(byAdding: .day, value: validityDays, to: lastDeployedDate) ??
            lastDeployedDate.addingTimeInterval(TimeInterval(validityDays * 86400))
    }
    
    public var daysRemaining: Int {
        let now = Date()
        if now >= expirationDate {
            return 0
        }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfExpDay = calendar.startOfDay(for: expirationDate)
        
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpDay)
        return max(0, components.day ?? 0)
    }
    
    public var isExpired: Bool {
        daysRemaining <= 0 || Date() >= expirationDate
    }
    
    public var tier: RenewalTier {
        if isExpired || daysRemaining <= 0 {
            return .expired
        } else if daysRemaining == 1 {
            return .critical
        } else if daysRemaining <= 3 {
            return .warning
        } else {
            return .safe
        }
    }
    
    public var badgeText: String {
        if isExpired || daysRemaining <= 0 {
            return "0d"
        }
        return "\(daysRemaining)d"
    }
    
    public var formattedFirstDeployed: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: firstDeployedDate)
    }
    
    public var formattedLastDeployed: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastDeployedDate)
    }
    
    public var formattedExpiration: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expirationDate)
    }
}

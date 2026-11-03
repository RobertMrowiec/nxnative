import Foundation

public struct UpdateInfo {
    public let hasUpdate: Bool
    public let localCommit: String
    public let remoteCommit: String
    public let commitMessages: [String]
    public let checkDate: Date
    public let repoURL: String
    public let upstreamBehindCount: Int
    public let upstreamCommitMessages: [String]
    public let upstreamRepoURL: String

    public init(
        hasUpdate: Bool,
        localCommit: String,
        remoteCommit: String,
        commitMessages: [String],
        checkDate: Date,
        repoURL: String,
        upstreamBehindCount: Int = 0,
        upstreamCommitMessages: [String] = [],
        upstreamRepoURL: String = "https://github.com/seedds/nxnative.git"
    ) {
        self.hasUpdate = hasUpdate
        self.localCommit = localCommit
        self.remoteCommit = remoteCommit
        self.commitMessages = commitMessages
        self.checkDate = checkDate
        self.repoURL = repoURL
        self.upstreamBehindCount = upstreamBehindCount
        self.upstreamCommitMessages = upstreamCommitMessages
        self.upstreamRepoURL = upstreamRepoURL
    }
}

public protocol UpdateCheckerDelegate: AnyObject {
    func updateCheckerDidFindUpdate(_ info: UpdateInfo)
    func updateCheckerDidProduceLog(_ message: String)
}

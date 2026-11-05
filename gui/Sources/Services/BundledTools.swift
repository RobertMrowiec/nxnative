import Foundation

/// Provides access to self-contained build tools and isolated Python runtime embedded in the application bundle.
public enum BundledTools {
    /// The app's Resources folder when running inside a valid `.app` bundle.
    public static var resources: URL? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return Bundle.main.resourceURL
    }

    public static func isExecutable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    /// Root directory of the `nxnative` repository.
    public static var nxnativeRootPath: String {
        SystemDetector.shared.detectNxnativeDirectory().path
    }

    /// Path to `Contents/Resources/tools/bin`, if present and non-empty.
    public static func binDirectory(in resURL: URL? = resources) -> String? {
        guard let dir = resURL?.appendingPathComponent("tools/bin"),
              (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.isEmpty == false else {
            return nil
        }
        return dir.path
    }

    /// Path to a specific tool in `Contents/Resources/tools/bin/<binary>`, if present and executable.
    public static func tool(_ binary: String, in resURL: URL? = resources) -> String? {
        guard let url = resURL?.appendingPathComponent("tools/bin/" + binary),
              isExecutable(url.path) else {
            return nil
        }
        return url.path
    }

    /// Path to the bundled Python interpreter (`Contents/Resources/python/bin/python3`), if present and executable.
    public static func python(in resURL: URL? = resources) -> String? {
        guard let url = resURL?.appendingPathComponent("python/bin/python3"),
              isExecutable(url.path) else {
            return nil
        }
        return url.path
    }

    /// Indicates whether a fully functional bundled Python is available.
    public static var isBundledPythonAvailable: Bool {
        python() != nil
    }

    /// Environment variables for processes executing the bundled Python:
    /// Disables user site-packages to avoid interference with system packages and disables bytecode writes into the signed bundle.
    public static func environment(for pyPath: String, in resURL: URL? = resources) -> [String: String] {
        guard let bundled = python(in: resURL), bundled == pyPath else { return [:] }
        return [
            "PYTHONNOUSERSITE": "1",
            "PYTHONDONTWRITEBYTECODE": "1"
        ]
    }

    /// Constructs an augmented PATH prioritizing bundled tools and bundled Python ahead of the system PATH.
    public static func augmentedPath(base: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                                    python pyPath: String? = nil,
                                    in resURL: URL? = resources) -> String {
        var dirs: [String] = []
        if let bin = binDirectory(in: resURL) {
            dirs.append(bin)
        }
        if let py = pyPath, py == python(in: resURL) {
            dirs.append((py as NSString).deletingLastPathComponent)
        }
        return (dirs + [base]).joined(separator: ":")
    }
}

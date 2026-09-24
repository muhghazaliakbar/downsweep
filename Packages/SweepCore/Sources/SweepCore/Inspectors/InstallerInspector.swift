import Foundation

/// Looks inside DMG, ZIP and PKG files for the app they install, then compares with what is installed.
public struct InstallerInspector: Sendable {
    public static let supportedExtensions: Set<String> = ["dmg", "zip", "pkg"]

    public var index: InstalledAppIndex
    public var timeout: TimeInterval

    public init(index: InstalledAppIndex, timeout: TimeInterval = 10) {
        self.index = index
        self.timeout = timeout
    }

    /// `nil` when the item is not an installer (or is a ZIP without an app inside).
    public func inspect(_ item: DownloadItem) async -> InstallerStatus? {
        guard !item.isDirectory, Self.supportedExtensions.contains(item.fileExtension) else { return nil }
        do {
            let bundle: AppBundleInfo? = switch item.fileExtension {
            case "dmg": try await appInDiskImage(item.url)
            case "zip": try await appInZip(item.url)
            default: try await appInPackage(item.url)
            }
            return bundle.map(status(for:))
        } catch SubprocessError.timedOut {
            return .uninspectable(reason: "timed out")
        } catch {
            return item.fileExtension == "zip" ? nil : .uninspectable(reason: "could not be opened")
        }
    }

    public func status(for bundle: AppBundleInfo) -> InstallerStatus {
        guard let installed = index.entry(for: bundle.bundleID) else { return .notInstalled(bundle) }
        let match = InstallerMatch(installer: bundle, installedVersion: installed.info.version, installedURL: installed.url)
        return AppVersion(installed.info.version) >= AppVersion(bundle.version)
            ? .installed(match)
            : .newerThanInstalled(match)
    }

    // MARK: - DMG

    /// Mounts read-only and hidden from Finder, reads the first app's Info.plist, always detaches.
    private func appInDiskImage(_ url: URL) async throws -> AppBundleInfo? {
        let mountRoot = FileManager.default.temporaryDirectory.appending(path: "Downsweep-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mountRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mountRoot) }

        let plist = try await Subprocess.run("/usr/bin/hdiutil", [
            "attach", url.path, "-readonly", "-nobrowse", "-noautoopen", "-noverify",
            "-plist", "-mountrandom", mountRoot.path,
        ], timeout: timeout)

        let mountPoints = Self.mountPoints(fromAttachOutput: plist)
        var found: AppBundleInfo?
        for mount in mountPoints where found == nil {
            found = Self.firstApp(in: mount)
        }
        for mount in mountPoints {
            _ = try? await Subprocess.run("/usr/bin/hdiutil", ["detach", mount.path, "-force"], timeout: timeout)
        }
        return found
    }

    static func mountPoints(fromAttachOutput data: Data) -> [URL] {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]]
        else { return [] }
        return entities.compactMap { $0["mount-point"] as? String }.map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    private static func firstApp(in folder: URL) -> AppBundleInfo? {
        let children = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for app in children where app.pathExtension == "app" {
            if let data = try? Data(contentsOf: app.appending(path: "Contents/Info.plist")),
               let info = AppBundleInfo(infoPlist: data, fallbackName: app.deletingPathExtension().lastPathComponent) {
                return info
            }
        }
        return nil
    }

    // MARK: - ZIP

    /// Reads only the archive listing and the one Info.plist, never extracts to disk.
    private func appInZip(_ url: URL) async throws -> AppBundleInfo? {
        let listing = try await Subprocess.run("/usr/bin/zipinfo", ["-1", url.path], timeout: timeout)
        guard let entry = Self.infoPlistEntry(inZipListing: String(decoding: listing, as: UTF8.self)) else { return nil }
        let data = try await Subprocess.run("/usr/bin/unzip", ["-p", url.path, entry], timeout: timeout)
        let appName = entry.split(separator: "/").first { $0.hasSuffix(".app") }.map { String($0.dropLast(4)) } ?? url.lastPathComponent
        return AppBundleInfo(infoPlist: data, fallbackName: appName)
    }

    /// The shallowest `Something.app/Contents/Info.plist`, ignoring `__MACOSX` resource forks.
    static func infoPlistEntry(inZipListing listing: String) -> String? {
        listing
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.hasPrefix("__MACOSX/") && $0.hasSuffix(".app/Contents/Info.plist") }
            .min { $0.count(of: "/") < $1.count(of: "/") }
    }

    // MARK: - PKG

    private func appInPackage(_ url: URL) async throws -> AppBundleInfo? {
        let workspace = FileManager.default.temporaryDirectory.appending(path: "Downsweep-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: workspace) }
        _ = try await Subprocess.run("/usr/sbin/pkgutil", ["--expand", url.path, workspace.path], timeout: timeout)

        let enumerator = FileManager.default.enumerator(at: workspace, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            guard file.lastPathComponent == "PackageInfo", let data = try? Data(contentsOf: file) else { continue }
            if let bundle = Self.appBundle(fromPackageInfo: data) { return bundle }
        }
        return nil
    }

    /// PackageInfo lists `<bundle id=… CFBundleShortVersionString=… path="./Foo.app"/>`; the top-level app wins.
    static func appBundle(fromPackageInfo data: Data) -> AppBundleInfo? {
        guard let document = try? XMLDocument(data: data),
              let bundles = try? document.nodes(forXPath: "//bundle") as? [XMLElement]
        else { return nil }
        let apps = bundles.compactMap { element -> (path: String, info: AppBundleInfo)? in
            guard let id = element.attribute(forName: "id")?.stringValue,
                  let path = element.attribute(forName: "path")?.stringValue,
                  path.hasSuffix(".app")
            else { return nil }
            let version = element.attribute(forName: "CFBundleShortVersionString")?.stringValue
                ?? element.attribute(forName: "CFBundleVersion")?.stringValue
                ?? "0"
            let name = URL(filePath: path).deletingPathExtension().lastPathComponent
            return (path, AppBundleInfo(bundleID: id, name: name, version: version))
        }
        return apps.min { $0.path.count(of: "/") < $1.path.count(of: "/") }?.info
    }
}

private extension String {
    func count(of character: Character) -> Int { reduce(0) { $1 == character ? $0 + 1 : $0 } }
}

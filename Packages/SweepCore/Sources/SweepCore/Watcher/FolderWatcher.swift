import CoreServices
import Foundation

/// Calls `onChange` after a folder settles. FSEvents coalesces bursts over `latency` seconds,
/// so a download in progress triggers one callback once writes pause, not one per chunk.
public final class FolderWatcher: @unchecked Sendable {
    private let url: URL
    private let latency: CFTimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "dev.downsweep.watcher")
    private var stream: FSEventStreamRef?

    public init(url: URL, latency: CFTimeInterval = 2, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.latency = latency
        self.onChange = onChange
    }

    deinit { stop() }

    public func start() {
        queue.sync {
            guard stream == nil else { return }
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil, release: nil, copyDescription: nil
            )
            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
            }
            guard let created = FSEventStreamCreate(
                kCFAllocatorDefault, callback, &context,
                [url.path] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                latency,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagIgnoreSelf)
            ) else { return }
            FSEventStreamSetDispatchQueue(created, queue)
            FSEventStreamStart(created)
            stream = created
        }
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

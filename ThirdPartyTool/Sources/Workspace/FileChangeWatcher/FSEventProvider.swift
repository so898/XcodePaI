import Foundation

public protocol FSEventProvider {
    func createEventStream(
        paths: CFArray,
        latency: CFTimeInterval,
        flags: UInt32,
        callback: @escaping FSEventStreamCallback,
        context: UnsafeMutablePointer<FSEventStreamContext>
    ) -> FSEventStreamRef?
    
    func startStream(_ stream: FSEventStreamRef)
    func stopStream(_ stream: FSEventStreamRef)
    func invalidateStream(_ stream: FSEventStreamRef)
    func releaseStream(_ stream: FSEventStreamRef)
    func setDispatchQueue(_ stream: FSEventStreamRef, queue: DispatchQueue)
}

class FileChangeWatcherFSEventProvider: FSEventProvider {
    init() {}
    
    func createEventStream(
        paths: CFArray,
        latency: CFTimeInterval,
        flags: UInt32,
        callback: @escaping FSEventStreamCallback,
        context: UnsafeMutablePointer<FSEventStreamContext>
    ) -> FSEventStreamRef? {
        return FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        )
    }
    
    func startStream(_ stream: FSEventStreamRef) {
        FSEventStreamStart(stream)
    }
    
    func stopStream(_ stream: FSEventStreamRef) {
        FSEventStreamStop(stream)
    }
    
    func invalidateStream(_ stream: FSEventStreamRef) {
        FSEventStreamInvalidate(stream)
    }
    
    func releaseStream(_ stream: FSEventStreamRef) {
        FSEventStreamRelease(stream)
    }
    
    func setDispatchQueue(_ stream: FSEventStreamRef, queue: DispatchQueue) {
        FSEventStreamSetDispatchQueue(stream, queue)
    }
}

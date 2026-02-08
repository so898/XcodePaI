//
//  LocalStorage.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/12.
//

import Foundation
import Combine
import Logger

/// Local Storage to store llm and other information
final class LocalStorage {
    
    // MARK: Shared Instance
    static let shared = LocalStorage()
    
    // MARK: Properties
    private let storageDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "xcodepai.localstorage.queue", attributes: .concurrent)
    private var changesSubject = PassthroughSubject<(String, Any?), Never>()
    
    // MARK: Initialization
    private init() {
        let documentsURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = documentsURL.appendingPathComponent("LocalStorage")
        
        createStorageDirectoryIfNeeded()
    }
    
    // Create Directory
    private func createStorageDirectoryIfNeeded() {
        queue.sync(flags: .barrier) {
            if !fileManager.fileExists(atPath: storageDirectory.path) {
                try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            }
        }
    }
    
    // Create File For Key
    private func fileURL(forKey key: String) -> URL {
        // Ignore unsafe chars in filename
        var safeKey = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        
        // replace key with hash if key is too long
        if safeKey.count > 50 {
            safeKey = String(safeKey.sha256().prefix(32))
        }
        
        return storageDirectory.appendingPathComponent("\(safeKey).json")
    }
    
    // MARK: Block-based API
    
    /// Save to file (Block)
    func setValue<T: Encodable>(_ value: T?, forKey key: String, completion: ((Error?) -> Void)? = nil) {
        let fileURL = fileURL(forKey: key)
        
        queue.async(flags: .barrier) {
            do {
                if let value = value {
                    // Encode value with json
                    let data = try self.encoder.encode(value)
                    try data.write(to: fileURL, options: [.atomicWrite])
                } else {
                    // Remove file with nil value
                    if self.fileManager.fileExists(atPath: fileURL.path) {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                }
                
                DispatchQueue.main.async {
                    self.changesSubject.send((key, value))
                    completion?(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }
    }
    
    /// Load from file (Block)
    func getValue<T: Decodable>(forKey key: String, completion: @escaping (T?) -> Void) {
        let fileURL = fileURL(forKey: key)
        
        queue.async {
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let value = try self.decoder.decode(T.self, from: data)
                DispatchQueue.main.async { completion(value) }
            } catch {
                Logger.storage.error("Load fail: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// Rename local file
    func renameStorage(oldKey: String, newKey: String) {
        let oldFileURL = fileURL(forKey: oldKey)
        let newFileURL = fileURL(forKey: newKey)
        
        queue.async(flags: .barrier) {
            guard self.fileManager.fileExists(atPath: oldFileURL.path) else {
                return
            }
            guard ((try? self.fileManager.moveItem(at: oldFileURL, to: newFileURL)) != nil) else {
                return
            }
        }
    }
    
    /// Remove local file
    func removeStorage(key: String) {
        let fileURL = fileURL(forKey: key)
        
        queue.async(flags: .barrier) {
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                return
            }
            guard ((try? self.fileManager.removeItem(at: fileURL)) != nil) else {
                return
            }
        }
    }
}

// MARK: Combine API
extension LocalStorage {
    /// Save to file (Combine)
    func save<T: Encodable>(_ value: T?, forKey key: String) -> AnyPublisher<Void, Never> {
        Future { [weak self] promise in
            self?.setValue(value, forKey: key) { error in
                if let error = error {
                    Logger.storage.error("save fail: \(error.localizedDescription)")
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Load from file (Combine)
    func fetch<T: Decodable>(forKey key: String) -> AnyPublisher<T?, Never> {
        Future { [weak self] promise in
            self?.getValue(forKey: key) { (value: T?) in
                promise(.success(value))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Observer value change (Combine)
    func publisher<T: Decodable>(forKey key: String) -> AnyPublisher<T?, Never> {
        return Deferred {
            self.fetch(forKey: key)
                .combineLatest(self.changesSubject
                    .filter { $0.0 == key }
                    .map { $0.1 as? T })
                .map { $0.0 }
                .prepend(self.fetch(forKey: key).first())
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Async/Await Extension
extension LocalStorage {
    
    /// Save to file (Async/Await)
    func setValue<T: Encodable>(_ value: T?, forKey key: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            setValue(value, forKey: key) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Load from file (Async/Await)
    func getValue<T: Decodable>(forKey key: String) async -> T? {
        return await withCheckedContinuation { continuation in
            getValue(forKey: key) { (value: T?) in
                continuation.resume(returning: value)
            }
        }
    }
}

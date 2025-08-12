//
//  Extensions.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation
import CryptoKit
import CommonCrypto

extension Date {
    static func currentTimeStamp() -> Int{
        return Int(Date().timeIntervalSince1970)
    }
}

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

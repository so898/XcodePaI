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

extension String {
    var localizedString: String {
        return NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
}

// MARK: Substring extension
extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }
    
    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }
    
    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}

extension Bundle {
    private static var languageBundleKey: UInt8 = 0
    
    static var currentLanguage: String? {
        get {
            return UserDefaults.standard.string(forKey: "AppLanguage")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AppLanguage")
            if let language = newValue, let path = Bundle.main.path(forResource: language, ofType: "lproj") {
                object_setClass(Bundle.main, CustomBundle.self)
                (Bundle.main as? CustomBundle)?.bundle = Bundle(path: path)
            } else {
                object_setClass(Bundle.main, CustomBundle.self)
                (Bundle.main as? CustomBundle)?.bundle = nil
            }
        }
    }
}

private class CustomBundle: Bundle, @unchecked Sendable {
    var bundle: Bundle?
    
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

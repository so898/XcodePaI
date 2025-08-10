//
//  Extensions.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/10.
//

import Foundation

extension Date {
    static func currentTimeStamp() -> Int{
        return Int(Date().timeIntervalSince1970)
    }
}

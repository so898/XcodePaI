//
//  Constraint.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/8/9.
//

import Foundation

class Constraint {
    // Static strings
    static let AppName = "XcodePaI"
    static let CRLFString = "\r\n"
    static let DoubleCRLFString = "\r\n\r\n"
    
    static let DoubleLFString = "\n\n"
    
    //Static Data
    static let CRLF = Data(Constraint.CRLFString.utf8)
    static let DoubleCRLF = Data(Constraint.DoubleCRLFString.utf8)
    static let DoubleLF = Data(Constraint.DoubleLFString.utf8)
}

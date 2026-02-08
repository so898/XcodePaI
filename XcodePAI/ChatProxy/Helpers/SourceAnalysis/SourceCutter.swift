//
//  SourceCutter.swift
//  XcodePAI
//
//  Created by Bill Cheng on 2025/10/14.
//

class SourceCutter {
    static func cut(source: String, fileType: String, filterKeys: [FilterKeyword]) -> String? {
        if fileType == "swift" {
            let result = SwiftSourceAnalyzer().analyzeSourceCode(source)
            let filtered = result.filter(with: filterKeys)
            let simplifiedCode = SwiftCodeGenerator().generateCode(from: filtered)
            
            return simplifiedCode.isEmpty ? nil : simplifiedCode
        } else if fileType == "objc" || fileType == "m" || fileType == "mm" {
            let implementationResult = ObjCImplementationAnalyzer().analyzeImplementationCode(source)
            
            let combinedResult = ObjCSourceAnalysisResult(
                interfaces: [],
                implementations: implementationResult.implementations
            )
            
            let filteredResult = combinedResult.filter(with: filterKeys)
            
            let simplifiedCode = ObjCCodeGenerator().generateCode(from: filteredResult)
            
            return simplifiedCode.isEmpty ? nil : simplifiedCode
        } else if fileType == "h" || fileType == "header" {
            let headerResult = ObjCHeaderAnalyzer().analyzeHeaderCode(source)
            
            let combinedResult = ObjCSourceAnalysisResult(
                interfaces: headerResult.interfaces,
                implementations: []
            )
            
            let filteredResult = combinedResult.filter(with: filterKeys)
            
            let simplifiedCode = ObjCCodeGenerator().generateCode(from: filteredResult)
            
            return simplifiedCode.isEmpty ? nil : simplifiedCode
        }
        return nil
    }
}

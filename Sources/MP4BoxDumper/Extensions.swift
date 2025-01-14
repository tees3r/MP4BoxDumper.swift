//
//  Extensions.swift
//  Core
//
//  Created by Tomoya Hirano on 2018/09/09.
//

import Foundation

extension InputStream {
    func read(maxLength: Int) -> (bytes: [UInt8], length: Int) {
        var tempArray = Array<UInt8>(repeating: 0, count: maxLength)
        let length = read(&tempArray, maxLength: maxLength) // TODO: optimise!! - use data directly without copying!
        
        return (tempArray, length)
    }
    
    func skip(length: Int) {
        _ = read(maxLength: length)
    }
    
    func readAsciiString(length: Int) -> String? {
        let (type, _) = read(maxLength: length)
        return String(data: Data(type), encoding: .ascii)
    }
}

extension Array where Element == UInt8 {
    
    var uint32Value: UInt32 {
        return UInt32(bigEndian: withUnsafeBytes { $0.load(as: UInt32.self) })
    }
    
    var uint64Value: UInt64 {
        return UInt64(bigEndian: withUnsafeBytes { $0.load(as: UInt64.self) })
    }
}

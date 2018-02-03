//
//  DataConversions.swift
//  Bluefruit
//
//  Created by Antonio García on 15/10/16.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

func hexDescription(data: Data, prefix: String = "", postfix: String = " ") -> String {
    return data.reduce("") {$0 + String(format: "%@%02X%@", prefix, $1, postfix)}
}

func hexDescription(bytes: [UInt8], prefix: String = "", postfix: String = " ") -> String {
    return bytes.reduce("") {$0 + String(format: "%@%02X%@", prefix, $1, postfix)}
}

func decimalDescription(data: Data, prefix: String = "", postfix: String = " ") -> String {
    return data.reduce("") {$0 + String(format: "%@%ld%@", prefix, $1, postfix)}
}

func stringToUInt8(string: String) -> [UInt8] {
    let str = string
    
    var startIndex = str.startIndex
    var result = [String]()
    
    repeat {
        let endIndex = startIndex.advanced(by: 2)
        result.append(str[startIndex..<endIndex])
        
        startIndex = endIndex
    } while startIndex < str.endIndex
    
    print("characteristicString result: \(result)")
    var newBytes = [UInt8]()
    for i in 0...result.count - 1 {
        print("result: \(result[i])")
        if let k = UInt8(result[i], radix: 16) {
            newBytes.append(k)
        }
    }
    return newBytes
}

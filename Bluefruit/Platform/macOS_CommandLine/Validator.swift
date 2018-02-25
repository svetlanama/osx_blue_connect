//
//  Validator.swift
//  Bluefruit
//
//  Created by Svitlana Moiseyenko on 2/25/18.
//  Copyright © 2018 Adafruit. All rights reserved.
//

import Foundation

final class Validator {
    class func validate(_ characteristicString: String, length: Int) -> Bool {
        if characteristicString.count == length {
            return true
        }
        return false
    }
    
    class func validate(uuid: String) -> Bool {
        //let pat = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"
        let pat = "[a-fA-F0-9]{8}(-|)[a-fA-F0-9]{4}(-|)[a-fA-F0-9]{4}(-|)[a-fA-F0-9]{4}(-|)[a-fA-F0-9]{12}"
        let regex = try! NSRegularExpression(pattern: pat, options: [])
        
        let matches = regex.matches(in: uuid, options: [], range: NSRange(location: 0, length: uuid.characters.count))
        
        return matches.count > 0 ? true : false
    }
    
    class func formattedUUID(uuidString: String) -> String {
        let uuid = uuidString.uppercased()
        let cleanUUID = uuid.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let mask = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX "
        
        var result = ""
        var index = cleanUUID.startIndex
        for ch in mask {
            if index == cleanUUID.endIndex {
                break
            }
            if ch == "X" {
                result.append(cleanUUID[index])
                index = cleanUUID.index(after: index)
            } else {
                result.append(ch)
            }
        }
        return result
    }
}


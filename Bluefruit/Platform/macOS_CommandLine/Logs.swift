//
//  Log.swift
//  Bluefruit
//
//  Created by Svitlana Moiseyenko on 2/25/18.
//  Copyright © 2018 Adafruit. All rights reserved.
//

import Foundation

struct Log {
    var uuid: String
    var time: String
    var characteristicData: (characteristicID: String, characteristicValue: String)
}

final class Logs {
    static let sharedInstance = Logs()
    
    
    var logs = [Log]()

    private init() {
        
    }
    
    func addLog(log: Log){
        logs.append(log)
    }
    
    func printLogs(){
        for log in logs {
            print("\(log.uuid) " +
                "time: \(String(describing: log.time)) " +
                "characteristic: \(String(describing: log.characteristicData.characteristicID)) - \(String(describing: log.characteristicData.characteristicValue.uppercased()))")
        }
    }
}

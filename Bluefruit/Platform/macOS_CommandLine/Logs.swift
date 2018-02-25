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
    var date: Date
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
        print("\n Logs \n")
        for log in logs {
            print("\(log.uuid) " +
                "time: \(dateToString(date: log.date)) " +
                "characteristic: \(String(describing: log.characteristicData.characteristicID)) - \(String(describing: log.characteristicData.characteristicValue.uppercased()))")
        }
    }
}

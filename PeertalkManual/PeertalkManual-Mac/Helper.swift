//
//  Helper.swift
//  PeertalkManual
//
//  Created by Kiran Kunigiri on 1/8/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Foundation

let PORT_NUMBER = 2345

extension String {
    
    /** A representation of the string in DispatchData form */
    var dispatchData: DispatchData {
        let data = self.data(using: .utf8)!
        let dispatchData = data.withUnsafeBytes {
            DispatchData(bytes: UnsafeBufferPointer(start: $0, count: data.count))
        }
        
        return dispatchData
    }
    
}

extension DispatchData {
    
    func toString() -> String {
        return String(bytes: self, encoding: .utf8)!
    }
    
    func toDictionary() -> NSDictionary {
        return NSDictionary.init(contentsOfDispatchData: self as __DispatchData)
    }
    
}

enum PTType: UInt32 {
    case count = 100
    case image = 101
}

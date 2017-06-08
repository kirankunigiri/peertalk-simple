//
//  Helper.swift
//  PeertalkManual
//
//  Created by Kiran Kunigiri on 1/8/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Foundation

let PORT_NUMBER = 4986

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
    
    /** Converts DispatchData back into a String format */
    func toString() -> String {
        return String(bytes: self, encoding: .utf8)!
    }

    /** Converts DispatchData back into a Dictionary format */
    func toDictionary() -> NSDictionary {
        return NSDictionary.init(contentsOfDispatchData: self as __DispatchData)
    }
    
}

/** The different types of data to be used with Peertalk */
enum PTType: UInt32 {
    case number = 100
    case image = 101
}

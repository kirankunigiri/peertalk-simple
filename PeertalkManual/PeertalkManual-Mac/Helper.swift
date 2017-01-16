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

enum PTFrame: UInt32 {
    case count = 100
    case message = 101
    case image = 102
}


// MARK: - Data extension for conversion
extension Data {
    
    /** Unarchive data into an object. It will be returned as type `Any` but you can cast it into the correct type. */
    func convert() -> Any {
        return NSKeyedUnarchiver.unarchiveObject(with: self)!
    }
    
    static func toData(object: Any) -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: object)
    }
    
}

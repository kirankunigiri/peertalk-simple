//
//  Helper.swift
//  PeertalkManual
//
//  Created by Kiran Kunigiri on 1/8/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import Foundation

extension String {
    
    var dispatchData: DispatchData {
        let data = "Hello World!".data(using: .utf8)!
        let dispatchData = data.withUnsafeBytes {
            DispatchData(bytes: UnsafeBufferPointer(start: $0, count: data.count))
        }
        return dispatchData
    }
    
}

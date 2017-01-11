//
//  ViewController.swift
//  PeertalkManual-iOS
//
//  Created by Kiran Kunigiri on 1/7/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    // Outlets
    @IBOutlet weak var label: UILabel!
    
    // Properties
    weak var serverChannel: PTChannel?
    weak var peerChannel: PTChannel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a channel and start listening
        let channel = PTChannel(delegate: self)
        channel?.listen(onPort: in_port_t(PORT_NUMBER), iPv4Address: INADDR_LOOPBACK, callback: { (error) in
            if error != nil {
                print("ERROR (Listening to post): \(error?.localizedDescription)")
            } else {
                self.serverChannel = channel
            }
        })
        
    }
    
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        if peerChannel != nil {
            let num = "\(Int(label.text!)! + 1)"
            self.label.text = num
            
            let d = NSKeyedArchiver.archivedData(withRootObject: "\(num)") as NSData
            self.sendData(data: d)
            
//            self.sendData(data: "\(num)".dispatchData)
        }
    }
    
    
    
    /** Closes the USB connectin */
    func closeConnection() {
        self.serverChannel?.close()
    }
    
    /** Sends data to the connected device */
    func sendData(data: NSData) {
        if peerChannel != nil {
            peerChannel?.sendFrame(ofType: PTFrame.message.rawValue, tag: PTFrameNoTag, withPayload: data.createReferencingDispatchData(), callback: { (error) in
                print(error?.localizedDescription ?? "Sent data")
            })
        }
    }

}



// MARK: - Channel Delegate
extension ViewController: PTChannelDelegate {
    
    func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        
        // Check if the channel is our connected channel; otherwise ignore it
        // TODO: Frame type checks
        if channel != peerChannel {
            return false
        } else {
            return true
        }
    }
    
    
    func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
        
        // Convert the data to a string
        let data = payload.dispatchData as DispatchData
        
        let nsData = NSData(contentsOfDispatchData: data as __DispatchData) as Data
        let message = nsData.convert() as! String
        
        
//        let message = String(bytes: data, encoding: .utf8)
        
        // Update the UI
        self.label.text = message
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error?) {
        print("ERROR (Connection ended): \(error?.localizedDescription)")
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didAcceptConnection otherChannel: PTChannel!, from address: PTAddress!) {
        
        // Cancel any existing connections
        if (peerChannel != nil) {
            peerChannel?.cancel()
        }
        
        // Update the peer channel and information
        peerChannel = otherChannel
        peerChannel?.userInfo = address
        
        print("Connected to channel")
    }
}











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
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    let imagePicker = UIImagePickerController()
    
    // Properties
    weak var serverChannel: PTChannel?
    weak var peerChannel: PTChannel?
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // UI Setup
        addButton.layer.cornerRadius = addButton.frame.height/2
        imageButton.layer.cornerRadius = imageButton.frame.height/2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
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
    
    @IBAction func addButtonTapped(_ sender: UIButton) {
        if peerChannel != nil {
            let num = "\(Int(label.text!)! + 1)"
            self.label.text = num
            
            let data = "\(num)".dispatchData
            self.sendData(data: data, type: PTFrame.count)
        }
    }
    
    @IBAction func imageButtonTapped(_ sender: UIButton) {
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    
    
    /** Closes the USB connectin */
    func closeConnection() {
        self.serverChannel?.close()
    }
    
    /** Sends data to the connected device */
    func sendData(data: NSData, type: PTFrame) {
        if peerChannel != nil {
            peerChannel?.sendFrame(ofType: type.rawValue, tag: PTFrameNoTag, withPayload: data.createReferencingDispatchData(), callback: { (error) in
                print(error?.localizedDescription ?? "Sent data")
            })
        }
    }
    
    /** Sends data to the connected device */
    func sendData(data: DispatchData, type: PTFrame) {
        if peerChannel != nil {
            peerChannel?.sendFrame(ofType: type.rawValue, tag: PTFrameNoTag, withPayload: data as __DispatchData! as __DispatchData, callback: { (error) in
                print(error?.localizedDescription ?? "Sent data")
            })
        }
    }

}



// MARK: - Channel Delegate
extension ViewController: PTChannelDelegate {
    
    func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
        
        // Check if the channel is our connected channel; otherwise ignore it
        // Optional: Check the frame type and optionally reject it
        if channel != peerChannel {
            return false
        } else {
            return true
        }
    }
    
    
    func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
        
        // Creates the data
        let dispatchData = payload.dispatchData as DispatchData
        let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
        
        // Check frame type
        if type == PTFrame.count.rawValue {
            let message = String(bytes: dispatchData, encoding: .utf8)
            self.label.text = message
        } else if type == PTFrame.image.rawValue {
            let image = UIImage(data: data)
            self.imageView.image = image
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error?) {
        print("ERROR (Connection ended): \(error?.localizedDescription)")
        self.statusLabel.text = "Status: Disconnected"
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
        self.statusLabel.text = "Status: Connected"
    }
}



extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.image = pickedImage
            let data = UIImageJPEGRepresentation(pickedImage, 1.0)!
            self.sendData(data: data as NSData, type: PTFrame.image)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}













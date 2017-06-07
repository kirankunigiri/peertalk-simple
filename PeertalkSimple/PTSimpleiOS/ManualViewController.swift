//
//  ViewController.swift
//  PeertalkManual-iOS
//
//  Created by Kiran Kunigiri on 1/7/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import UIKit

class ManualViewController: UIViewController {

    // Outlets
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    // Properties
    weak var serverChannel: PTChannel?
    weak var peerChannel: PTChannel?
    let imagePicker = UIImagePickerController()
    
    
    // UI Setup
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        addButton.layer.cornerRadius = addButton.frame.height/2
        imageButton.layer.cornerRadius = imageButton.frame.height/2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a channel and start listening
        let channel = PTChannel(delegate: self)
        
        // Create a custom port number that the connection will use. I have declared it in the Helper.swift file
        // Make sure the Mac app uses the same number. Any 4 digit integer will work fine.
        channel?.listen(onPort: in_port_t(PORT_NUMBER), iPv4Address: INADDR_LOOPBACK, callback: { (error) in
            if error != nil {
                print("ERROR (Listening to post): \(error?.localizedDescription ?? "-1")")
            } else {
                self.serverChannel = channel
            }
        })
        
        // Setup imagge picker
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    // Add 1 to our counter label and send the data if the device is connected
    @IBAction func addButtonTapped(_ sender: UIButton) {
        if isConnected() {
            // Get the new counter number
            let num = "\(Int(label.text!)! + 1)"
            self.label.text = num
            
            // Here, you can create data in two different ways
            // For convenience, I describe both methods in this (iOS) demo, and not in the mac demo (because it's the same)
            // Check out the Helper.swift and the bottom of the PTManager.swift for class extensions that can speed this up
            
            // The first way is to directly create DispatchData from your object. This method is different for each object type.
            // The following, for example, is how to convert Strings
            // WARNING: DispatchData created this way is NOT compatible with DispatchData created using the second method. Always only use one or the other
            
            // let data = "\(num)".data(using: .utf8)!
            // let dispatchData = data.withUnsafeBytes {
            //     DispatchData(bytes: UnsafeBufferPointer(start: $0, count: data.count))
            // }
            // let final = dispatchData as __DispatchData
            
            
            // There is, however, a simpler universal way that works for all object types. 
            // First, we convert the String to data using the NSKeyedArchiver class and then casting it to NSData
            // Next, we can convert it to DispatchData by using the createReferencingDispatchData method (it's only available in the NSData class, which is why we casted it)
            
            let data = NSKeyedArchiver.archivedData(withRootObject: num) as NSData
            self.sendData(data: data.createReferencingDispatchData(), type: PTType.number)
        }
    }
    
    // Present the image picker if the device is connected
    @IBAction func imageButtonTapped(_ sender: UIButton) {
        if isConnected() {
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    /** Checks if the device is connected, and presents an alert view if it is not */
    func isConnected() -> Bool {
        if peerChannel == nil {
            let alert = UIAlertController(title: "Disconnected", message: "Please connect to a device first", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        return peerChannel != nil
    }
    
    
    
    /** Closes the USB connectin */
    func closeConnection() {
        self.serverChannel?.close()
    }
    
    /** Sends data to the connected device */
    func sendData(data: __DispatchData, type: PTType) {
        if peerChannel != nil {
            peerChannel?.sendFrame(ofType: type.rawValue, tag: PTFrameNoTag, withPayload: data, callback: { (error) in
                print(error?.localizedDescription ?? "Sent data")
            })
        }
    }

}



// MARK: - Channel Delegate
extension ManualViewController: PTChannelDelegate {
    
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
        
        // Create the data objects
        let dispatchData = payload.dispatchData as DispatchData
        let data = NSData(contentsOfDispatchData: dispatchData as __DispatchData) as Data
        
        // Check frame type
        if type == PTType.number.rawValue {
            
            // The first conversion method of DispatchData (explained in the addButtonTapped method)
            // let message = String(bytes: dispatchData, encoding: .utf8)
            
            // The second, universal method of conversion (Using NSKeyedUnarchiver)
            let count = NSKeyedUnarchiver.unarchiveObject(with: data) as! Int
            
            // Update the UI
            self.label.text = "\(count)"
            
        } else if type == PTType.image.rawValue {
            
            // Conver the image and update the UI
            let image = UIImage(data: data)
            self.imageView.image = image
            
        }
    }
    
    func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error?) {
        print("ERROR (Connection ended): \(String(describing: error?.localizedDescription))")
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
        print("SUCCESS (Connected to channel)")
        self.statusLabel.text = "Status: Connected"
    }
}



// MARK: - Image Picker Delegate
extension ManualViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Get the image and send it
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // Get the picked image
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        // Update our UI on the main thread
        self.imageView.image = image
        
        // Send the data on the background thread to make sure the UI does not freeze
        DispatchQueue.global(qos: .background).async {
            // Convert the data using the second universal method
            let data = UIImageJPEGRepresentation(image, 1.0)!
            let dispatchData = (data as NSData).createReferencingDispatchData()!
            self.sendData(data: dispatchData, type: PTType.image)
        }
        
        // Dismiss the image picker
        dismiss(animated: true, completion: nil)
    }
    
    // Dismiss the view
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}













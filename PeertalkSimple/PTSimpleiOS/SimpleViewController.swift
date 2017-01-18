//
//  PTSimpleViewController.swift
//  PeertalkManual
//
//  Created by Kiran Kunigiri on 1/16/17.
//  Copyright © 2017 Kiran. All rights reserved.
//

import UIKit

class SimpleViewController: UIViewController {

    // Outlets
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    // Properties
    let peertalk = PTManager()
    let imagePicker = UIImagePickerController()
    
    // UI Setup
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        addButton.layer.cornerRadius = addButton.frame.height/2
        imageButton.layer.cornerRadius = imageButton.frame.height/2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup peertalk
        peertalk.delegate = self
        peertalk.connect(portNumber: PORT_NUMBER)
        
        // Setup imagge picker
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }

    @IBAction func addButtonTapped(_ sender: UIButton) {
        if peertalk.isConnected {
            let num = Int(label.text!)! + 1
            self.label.text = "\(num)"
            peertalk.sendObject(object: num, type: PTType.count.rawValue)
        } else {
            showAlert()
        }
    }
    
    @IBAction func imageButtonTapped(_ sender: UIButton) {
        if peertalk.isConnected {
            self.present(imagePicker, animated: true, completion: nil)
        } else {
            showAlert()
        }
    }
    
    func showAlert() {
        let alert = UIAlertController(title: "Disconnected", message: "Please connect to a device first", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}



extension SimpleViewController: PTManagerDelegate {
    
    func shouldAcceptDataOfType(type: UInt32) -> Bool {
        return true
    }
    
    func didReceiveDataOfType(type: UInt32, data: Data) {
        if type == PTType.count.rawValue {
            let count = data.convert() as! Int
            self.label.text = "\(count)"
        } else if type == PTType.image.rawValue {
            let image = UIImage(data: data) 
            self.imageView.image = image
        }
    }
    
    func connectionDidChange(connected: Bool) {
        self.statusLabel.text = connected ? "Connected" : "Disconnected"
    }
    
}



extension SimpleViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Get the image and send it
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // Get the picked image
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        // Update our UI on the main thread
        self.imageView.image = image
        
        // Send the data on the background thread to make sure the UI does not freeze
        DispatchQueue.global(qos: .background).async {
            let data = UIImageJPEGRepresentation(image, 1.0)!
            self.peertalk.sendData(data: data, type: PTType.image.rawValue, completion: nil)
        }
        
        // Dismiss the image picker
        dismiss(animated: true, completion: nil)
    }
    
    // Dismiss the view
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}

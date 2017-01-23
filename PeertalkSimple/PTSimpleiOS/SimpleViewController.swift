//
//  PTSimpleViewController.swift
//  ptManagerManual
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
    let ptManager = PTManager.instance
    let imagePicker = UIImagePickerController()
    
    // UI Setup
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        addButton.layer.cornerRadius = addButton.frame.height/2
        imageButton.layer.cornerRadius = imageButton.frame.height/2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the PTManager
        ptManager.delegate = self
        ptManager.connect(portNumber: PORT_NUMBER)
        
        // Setup imagge picker
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }

    @IBAction func addButtonTapped(_ sender: UIButton) {
        if ptManager.isConnected {
            let num = Int(label.text!)! + 1
            self.label.text = "\(num)"
            ptManager.sendObject(object: num, type: PTType.number.rawValue)
        } else {
            showAlert()
        }
    }
    
    @IBAction func imageButtonTapped(_ sender: UIButton) {
        if ptManager.isConnected {
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
    
    func peertalk(shouldAcceptDataOfType type: UInt32) -> Bool {
        return true
    }
    
    func peertalk(didReceiveData data: Data, ofType type: UInt32) {
        if type == PTType.number.rawValue {
            let count = data.convert() as! Int
            self.label.text = "\(count)"
        } else if type == PTType.image.rawValue {
            let image = UIImage(data: data)
            self.imageView.image = image
        }
    }
    
    func peertalk(didChangeConnection connected: Bool) {
        print("Connection: \(connected)")
        self.statusLabel.text = connected ? "Connected" : "Disconnected"
    }
    
}



extension SimpleViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        self.imageView.image = image
        
        DispatchQueue.global(qos: .background).async {
            let data = UIImageJPEGRepresentation(image, 1.0)!
            self.ptManager.sendData(data: data, type: PTType.image.rawValue, completion: nil)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}

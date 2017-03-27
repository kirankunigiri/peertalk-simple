# peertalk-simple ![Platform](https://img.shields.io/badge/platform-iOS+macOS-677cf4.svg)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Build Passing](https://img.shields.io/badge/build-passing-brightgreen.svg)

This library simplifies [peertalk](https://github.com/rsms/peertalk) by Rasmus, and allows for simplified communication between iOS and Mac devices via USB. This project contains 2 things.

- A **detailed tutorial** on how to use peertalk
  - Lengthy and complex
  - Allows for full customizability of data transfers
  - Read the commented ManualViewController classes for a tutorial
- A **facade class** that simplifies peertalk
  - Setup is extremely quick and simple
  - Code is the exact same on iOS and macOS
  - Read the guide below for a tutorial

In the Xcode project, there are 2 targets (for iOS and macOS) with demos of peertalk as seen in the gif above. Each one has 2 View Controller files named Manual and Simple. As you can guess, navigate to the Manual classes for a detailed tutorial on how to implement peertalk yourself. It is filled with comments and clean swift code for you to read. On the other hand, the Simple classes contain a quick demo of using the facade class.

## Demo

 ![Demo](Images/PeertalkDemo.gif)

## Installation

Just drag the PTManager.swift file to your project, and you'll be all set to go.

## Guide

PTManager is a facade class that manages all the different peertalk components so that you can easily manage communication with just one object. **The best part is, the code is the exact same on both iOS and macOS!** While manual peertalk had a completely different setup for the two, you can literally copy and paste code from one to another with PTManager. Let's walk through how simple the process is!

#### Setup

To begin, let's setup the PTManager singleton instance by setting the delegate and starting the connection with a port number. The port number can be any 4 digit integer, and the Mac app must use the same one to connect.

```swift
PTManager.instance.delegate = self
PTManager.instance.connect(portNumber: 2345)
```

Next, we also need to run a method in the App Delegate when the app restarts because peertalk automatically disconnects when the iPhone is put to sleep.

```swift
func applicationDidBecomeActive(_ application: UIApplication) {
    PTManager.instance.connect(portNumber: 2345)
}
```

#### Send Data

You can add a tag to the data you send so that the receiver knows what the data is. You can create a `UInt32` enum to manage them. Here's an example with 2 types: strings and images.

```swift
enum PTType: UInt32 {
    case string = 100
    case image = 101
}
```

Now, let's send a String! Family automatically converts objects to data using `NSKeyedArchiver`, so if you want to send your own data, use the `sendData` method instead.

```swift
ptManager.sendObject(object: "Hello World", type: PTType.string.rawValue)
```

#### Receive Data (Protocol)

Let's receive data now! We just need to conform to the PTManagerDelegate protocol.

The other methods give you other information about your devices and data, but the `didReceiveDataOfType` method is where you can actually receive and use data. Here, I check the type of the data and convert it to the corresponding object. The class has an extension to the Data class - the method `convert()` - that uses the NSKeyedArchiver class to convert data back into the object you need.

```swift

// You can reject data before receiving it if it is a certain type
// Because I always want to accept the data, I return true no matter what
func peertalk(shouldAcceptDataOfType type: UInt32) -> Bool {
    return true
}

// With the data, you can convert it based on it's type
func peertalk(didReceiveData data: Data, ofType type: UInt32) {
    if type == PTType.string.rawValue {
        let string = data.convert() as! String
    } else if type == PTType.image.rawValue {
        let image = UIImage(data: data)
    }
}

// You can perform any updates when the connection status changes
func peertalk(didChangeConnection connected: Bool) {}
```

And that's how simple it is to use! Remember, PTManager works the same across iOS and macOS, so you can resuse the same code.

## Contribute
Feel free to to contribute to the project with a pull request or open up an issue for any new features or bug fixes.
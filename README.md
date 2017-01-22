# peertalk-simple ![License MIT](https://img.shields.io/badge/platform-iOS+macOS-677cf4.svg)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![License MIT](https://img.shields.io/badge/build-passing-brightgreen.svg)

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

 ![Upload](Images/PeertalkDemo.gif)

## Installation

Just drag the PTManager.swift file to your project, and you'll be all set to go.

## Guide

PTManager is a facade class that manages all the different peertalk components so that you can easily manage communication with just one object. **The best part is, the code is the exact same on both iOS and macOS!** While manual peertalk had a completely different setup for the two, you can literally copy and paste code from one to another with PTManager. Let's walk through how simple the process is!

#### Setup

To begin, let's create a PTManager object, and also create a port number. The port number can be any 4 digit integer, and the Mac app must use the same one to connect.

```swift
let ptManager = PTManager()
let PORT_NUMBER 2345
```

Next, let's set the delegate and start the connection with the specified port number.

```swift
ptManager.delegate = self
ptManager.connect(portNumber: PORT_NUMBER)
```

#### Send Data

We can start sending data now! Peertalk can send DispatchData, Data, and also any type of object (it automatically converts it to data). However, if we send multiple objects (such as images or dictionaries), we need a way to know which type of object we sent so that we can convert it back. We can actually use an enum to send the type of object we sent! Here's a small example.

I've created an enum called PTType, and I've created 2 types - strings and images.

```swift
enum PTType: UInt32 {
    case string = 100
    case image = 101
}
```

Now, let's send a String!

```swift
ptManager.sendObject(object: "Hello World", type: PTType.string.rawValue)
```

#### Receive Data (Protocol)

Let's receive data now! We just need to conform to the PTManagerDelegate protocol.

The other methods give you other information about your devices and data, but the `didReceiveDataOfType` method is where you can actually receive and use data. Here, I check the type of the data using our enum, and convert it to the corresponding object! PTManager uses the NSKeyedArchiver class to convert objects to data, so I've added an extension to the Data class - the method `convert()` - that you can use to return it to the specified type.

```swift

// You can reject data before receiving it if it is a certain type
// Because I always want to accept the data, I return true no matter what
func shouldAcceptDataOfType(type: UInt32) -> Bool {
    return true
}

// With the data, you can convert it based on it's type
func didReceiveDataOfType(type: UInt32, data: Data) {
    if type == PTType.string.rawValue {
        let string = data.convert() as! Int
    } else if type == PTType.image.rawValue {
        let image = UIImage(data: data)
    }
}

// You can perform any updates when the connection status changes
func connectionDidChange(connected: Bool) {}
```

And that's how simple it is to use! Remember, PTManager works the same across iOS and macOS, so you can resuse the same code.

## Contribute
Feel free to to contribute to the project with a pull request or open up an issue for any new features or bug fixes.


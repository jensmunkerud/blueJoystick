//
//  ViewController.swift
//  blueJoystick
//
//  Created by Jens Munkerud on 16/10/2024.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create an instance of JoystickView
        let joystick = JoystickView(frame: CGRect(x: 100, y: 400, width: 200, height: 200))
        
        // Handle joystick movements
        joystick.joystickMoved = { (xValue, yValue) in
            print("Joystick moved: X: \(xValue), Y: \(yValue)")
        }
        
        // Add the joystick to the main view
        view.addSubview(joystick)
    }
}



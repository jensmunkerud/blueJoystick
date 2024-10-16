//
//  JoystickView.swift
//  blueJoystick
//
//  Created by Jens Munkerud on 16/10/2024.
//

import UIKit

class JoystickView: UIView {

    private let joystickRadius: CGFloat = 50.0
    private let baseRadius: CGFloat = 100.0
    
    private var stickView = UIView()
    private var baseView = UIView()

    // Callbacks for updating the joystick direction
    var joystickMoved: ((_ xValue: CGFloat, _ yValue: CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupJoystick()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupJoystick()
    }
    
    private func setupJoystick() {
        // Setup the base view (circular base)
        baseView.frame = CGRect(x: 0, y: 0, width: baseRadius * 2, height: baseRadius * 2)
        baseView.center = CGPoint(x: bounds.midX + 20, y: bounds.midY + 20)
        baseView.layer.cornerRadius = baseRadius
        baseView.backgroundColor = .lightGray
        baseView.alpha = 0.6
        addSubview(baseView)
        
        // Setup the stick view (movable part)
        stickView.frame = CGRect(x: 0, y: 0, width: joystickRadius * 2, height: joystickRadius * 2)
        stickView.center = baseView.center
        stickView.layer.cornerRadius = joystickRadius
        stickView.backgroundColor = .darkGray
        addSubview(stickView)

        // Adding Pan Gesture for moving the stick
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        stickView.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let baseCenter = CGPoint(x: bounds.midX + 20, y: bounds.midY + 20)
        
        let distance = sqrt(pow(translation.x, 2) + pow(translation.y, 2))
        let maxDistance = baseRadius
        
        // Limit the stick movement within the base circle
        var x = translation.x
        var y = translation.y
        
        if distance > maxDistance {
            let angle = atan2(translation.y, translation.x)
            x = cos(angle) * maxDistance
            y = sin(angle) * maxDistance
        }
        
        switch gesture.state {
        case .changed:
            stickView.center = CGPoint(x: baseCenter.x + x, y: baseCenter.y + y)
            
            // Normalize the joystick position for output
            let normalizedX = x / maxDistance
            let normalizedY = y / maxDistance
            joystickMoved?(normalizedX, normalizedY)
            
        case .ended, .cancelled:
            // Reset stick position
            UIView.animate(withDuration: 0.2) {
                self.stickView.center = baseCenter
            }
            joystickMoved?(0, 0)
            
        default:
            break
        }
    }
}

//
//  ViewController.swift
//  blueJoystick
//
//  Created by Jens Munkerud on 16/10/2024.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource {

    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var peripheral: CBPeripheral?
    
    // Bluetooth characteristics for X and Y coordinates
    var xCharacteristic: CBCharacteristic?
    var yCharacteristic: CBCharacteristic?

    // UITableView to display nearby devices
    var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize CBCentralManager for Bluetooth functionality
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Create a Bluetooth scan button in the top-left corner
        let scanButton = UIButton(type: .system)
        scanButton.frame = CGRect(x: 20, y: 50, width: 100, height: 30)  // Adjust as needed
        scanButton.setTitle("Scan", for: .normal)
        scanButton.addTarget(self, action: #selector(startScanning), for: .touchUpInside)
        view.addSubview(scanButton)

        // Create a UITableView to display Bluetooth devices
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isHidden = true  // Initially hidden until devices are discovered
        view.addSubview(tableView)

        // Create an instance of JoystickView
        let joystickSize: CGFloat = 200
        let joystick = JoystickView(frame: CGRect(x: 0, y: 0, width: joystickSize, height: joystickSize))

        // Center the joystick in the middle of the screen
        joystick.center = view.center

        // Handle joystick movements and send to Bluetooth device
        joystick.joystickMoved = { (xValue, yValue) in
            print("Joystick moved: X: \(xValue), Y: \(yValue)")
            self.sendJoystickData(xValue: xValue, yValue: yValue)
        }

        // Add the joystick to the main view
        view.addSubview(joystick)
    }

    @objc func startScanning() {
        if centralManager.state == .poweredOn {
            discoveredPeripherals.removeAll()  // Clear previously discovered devices
            tableView.reloadData()  // Clear the table view
            centralManager.scanForPeripherals(withServices: nil, options: nil)  // Start scanning
            print("Scanning for devices...")
        } else {
            print("Bluetooth is not available.")
        }
    }

    // CBCentralManagerDelegate method: Called when Bluetooth state changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on and ready")
        case .poweredOff:
            print("Bluetooth is turned off")
        case .unsupported:
            print("Bluetooth is not supported on this device")
        default:
            print("Bluetooth state unknown")
        }
    }

    // CBCentralManagerDelegate method: Called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered: \(peripheral.name ?? "Unnamed device")")

        // Check if the peripheral is already in the list
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)  // Add the peripheral to the list
            tableView.reloadData()  // Refresh the table view to display the new device
        }

        // Show the tableView once devices are discovered
        tableView.isHidden = false
    }

    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredPeripherals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let peripheral = discoveredPeripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name ?? "Unnamed device"
        return cell
    }

    // UITableViewDelegate method: Called when a device is selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPeripheral = discoveredPeripherals[indexPath.row]
        centralManager.connect(selectedPeripheral, options: nil)
        peripheral = selectedPeripheral
        peripheral?.delegate = self
        print("Connecting to: \(selectedPeripheral.name ?? "Unnamed device")")

        // Hide the table view after selecting the device
        tableView.isHidden = true

        // Stop scanning for devices
        centralManager.stopScan()
    }

    // CBCentralManagerDelegate method: Called when a peripheral is connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to: \(peripheral.name ?? "Unnamed device")")
        peripheral.discoverServices([CBUUID(string: "ceeeeeee-c666-499f-b917-352312f159c5")])
    }

    // CBPeripheralDelegate method: Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }

        for service in peripheral.services ?? [] {
            print("Discovered service: \(service.uuid)")
            if service.uuid == CBUUID(string: "ceeeeeee-c666-499f-b917-352312f159c5") {
                peripheral.discoverCharacteristics([CBUUID(string: "aaaaaaaa-d2a0-44c8-a271-69ef24094b01"), CBUUID(string: "bbbbbbbb-f0a9-4623-b503-ee7804fca301")], for: service)
            }
        }
    }

    // CBPeripheralDelegate method: Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == CBUUID(string: "aaaaaaaa-d2a0-44c8-a271-69ef24094b01") {
                xCharacteristic = characteristic
                print("X characteristic found")
            } else if characteristic.uuid == CBUUID(string: "bbbbbbbb-f0a9-4623-b503-ee7804fca301") {
                yCharacteristic = characteristic
                print("Y characteristic found")
            }
        }
    }

    // Method to send joystick data to the connected Bluetooth device
    func sendJoystickData(xValue: CGFloat, yValue: CGFloat) {
        guard let peripheral = peripheral else {
            print("No Bluetooth device connected.")
            return
        }

        // Send X value to the X characteristic
        if let xCharacteristic = xCharacteristic {
            let xData = "\(xValue)".data(using: .utf8)!
            peripheral.writeValue(xData, for: xCharacteristic, type: .withResponse)
            print("Sent X data: \(xValue)")
        }

        // Send Y value to the Y characteristic
        if let yCharacteristic = yCharacteristic {
            let yData = "\(yValue)".data(using: .utf8)!
            peripheral.writeValue(yData, for: yCharacteristic, type: .withResponse)
            print("Sent Y data: \(yValue)")
        }
    }
}

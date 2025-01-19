import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource {

    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var peripheral: CBPeripheral?
    
    var xCharacteristic: CBCharacteristic?
    var yCharacteristic: CBCharacteristic?
    var extendInnerCharacteristic: CBCharacteristic?
    var extendOuterCharacteristic: CBCharacteristic?
    var controlCharacteristic: CBCharacteristic?
    var stageCharacteristic: CBCharacteristic?
    
    var tableView: UITableView!
    var scanButton: UIButton!
    
    let lightBlue = UIColor(red: 0.68, green: 0.85, blue: 1.0, alpha: 1.0)
    
    var smoothToggleButton: UIButton!
    var upperButton: UIButton!
    var lowerButton: UIButton!
    var isSmoothMode = true // Track the state of Smooth/Instant mode
    var upperSelected = true
    var lowerSelected = true

    
    var retractIButton: UIButton!
    var extendIButton: UIButton!
    var retractOButton: UIButton!
    var extendOButton: UIButton!
    var resetButton: UIButton!
    var outerButtonContainer: UIView!
    var innerButtonContainer: UIView!
    
    var retractInner = false
    var extendInner = false

    var latestXValue: CGFloat = 0.0
    var latestYValue: CGFloat = 0.0
    
    var heartbeatTimer: Timer?

    // UI elements
    var joystick: JoystickView!
    var verticalSlider: UISlider!
    var horizontalSlider: UISlider!
    var controlModeToggleButton: UIButton!
    var isJoystickMode = false  // Keeps track of current mode (joystick or sliders)
    var xyLabel: UILabel!  // Label to display current X and Y values

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Bluetooth CentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Starts heatbeat to keep BLE connection active
        startHeartbeat()
        
        // Setup the scan button, placed on top of other views
        scanButton = UIButton(type: .system)
        scanButton.frame = CGRect(x: 20, y: 50, width: 100, height: 30)
        scanButton.setTitle("Scan", for: .normal)
        scanButton.addTarget(self, action: #selector(toggleScanMenu), for: .touchUpInside)
        view.addSubview(scanButton)

        // TableView for Bluetooth devices, configured to be solid and block all touches
        tableView = UITableView(frame: CGRect(x: 0, y: 80, width: view.bounds.width, height: view.bounds.height - 80), style: .plain)
        tableView.isOpaque = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isHidden = true  // Initially hidden
        tableView.backgroundColor = UIColor.black
        view.addSubview(tableView)

        // Bring scan button to front so it remains accessible
        view.bringSubviewToFront(scanButton)
        // Setup joystick
        setupJoystick()

        // Setup sliders
        setupSliders()

        // Toggle button for switching between joystick and sliders
        setupToggleControlButton()

        // Setup label to display current X and Y values
        setupXYLabel()
        
        setupSmoothToggleButton()
        setupUpperLowerButtons()
        
        view.bringSubviewToFront(tableView)
    }

    
    
    func startHeartbeat() {
        // Stop any existing timer first
        stopHeartbeat()
        
        // Start a new timer that sends data every 5 seconds (adjust interval as needed)
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sendHeartbeat()
        }
    }
    
    func sendHeartbeat() {
        // Send a packet with neutral values (e.g., 0,0) to keep the connection alive
        sendJoystickData(xValue: latestXValue, yValue: latestYValue)
    }


    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from: \(peripheral.name ?? "Unnamed device")")
        stopHeartbeat()
    }



    func setupJoystick() {
        let joystickSize: CGFloat = 200
        joystick = JoystickView(frame: CGRect(x: 0, y: 0, width: joystickSize, height: joystickSize))
        joystick.center = view.center
        joystick.joystickMoved = { [weak self] (xValue, yValue) in
            guard let self = self else { return }
            self.latestXValue = xValue
            self.latestYValue = -yValue
            self.updateXYLabel()  // Update the X and Y values on the screen
            self.sendJoystickData(xValue: xValue, yValue: -yValue)  // Send immediately
        }
        joystick.isHidden = !isJoystickMode
        view.addSubview(joystick)
    }

    func setupSliders() {
            let sliderLength: CGFloat = 300

            // Vertical Slider
            verticalSlider = UISlider(frame: CGRect(x: view.bounds.midX - 150, y: view.bounds.midY - sliderLength / 1.5 + 50, width: sliderLength, height: sliderLength / 2))
            verticalSlider.minimumValue = -1.0
            verticalSlider.maximumValue = 1.0
            verticalSlider.value = 0.0
            verticalSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))
            verticalSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
            verticalSlider.isContinuous = true
            verticalSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
            verticalSlider.isHidden = isJoystickMode
            view.addSubview(verticalSlider)

            // Horizontal Slider
            horizontalSlider = UISlider(frame: CGRect(x: view.bounds.midX - sliderLength / 2, y: view.bounds.midY + 130, width: sliderLength, height: 40))
            horizontalSlider.minimumValue = -1.0
            horizontalSlider.maximumValue = 1.0
            horizontalSlider.value = 0.0
            horizontalSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
            horizontalSlider.isContinuous = true
            horizontalSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
            horizontalSlider.isHidden = isJoystickMode
            view.addSubview(horizontalSlider)

            // Add Retract and Extend buttons
            setupExtendRetractButtons()
        }

    func setupExtendRetractButtons() {
        // Create a background view for the Inner buttons
        innerButtonContainer = UIView(frame: CGRect(x: view.bounds.midX - 160, y: view.bounds.midY - 50, width: 100, height: 140))
        innerButtonContainer.backgroundColor = UIColor(white: 0.9, alpha: 0.1)
        innerButtonContainer.layer.cornerRadius = 15
        innerButtonContainer.layer.shadowColor = UIColor.black.cgColor
        innerButtonContainer.layer.shadowOpacity = 0.2
        innerButtonContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        innerButtonContainer.layer.shadowRadius = 4
        view.addSubview(innerButtonContainer)
        innerButtonContainer.isHidden = isJoystickMode
        // Lower Label
        
        let lowerLabel = UILabel(frame: CGRect(x: 0, y: 0, width: innerButtonContainer.frame.width, height: 20))
        lowerLabel.text = "Inner"
        lowerLabel.textColor = .darkGray
        lowerLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lowerLabel.textAlignment = .center
        innerButtonContainer.addSubview(lowerLabel)
        
        // Retract Inner Button
        retractIButton = UIButton(type: .system)
        retractIButton.frame = CGRect(x: view.bounds.midX - 150, y: view.bounds.midY + 30, width: 80, height: 50)
        retractIButton.setTitle("Retract", for: .normal)
        retractIButton.addTarget(self, action: #selector(retractIPressed), for: .touchDown)
        retractIButton.addTarget(self, action: #selector(retractIReleased), for: .touchUpInside)
        retractIButton.addTarget(self, action: #selector(retractIReleased), for: .touchUpOutside)
        retractIButton.isHidden = isJoystickMode
        styleButton(retractIButton)
        view.addSubview(retractIButton)

        // Extend Inner Button
        extendIButton = UIButton(type: .system)
        extendIButton.frame = CGRect(x: view.bounds.midX - 150, y: view.bounds.midY - 30, width: 80, height: 50)
        extendIButton.setTitle("Extend", for: .normal)
        extendIButton.addTarget(self, action: #selector(extendIPressed), for: .touchDown)
        extendIButton.addTarget(self, action: #selector(extendIReleased), for: .touchUpInside)
        extendIButton.addTarget(self, action: #selector(extendIReleased), for: .touchUpOutside)
        extendIButton.isHidden = isJoystickMode
        styleButton(extendIButton)
        view.addSubview(extendIButton)
        
        // Retract Outer Button
        retractOButton = UIButton(type: .system)
        retractOButton.frame = CGRect(x: view.bounds.midX - 150, y: view.bounds.midY - 120, width: 80, height: 50)
        retractOButton.setTitle("Retract", for: .normal)
        retractOButton.addTarget(self, action: #selector(retractOPressed), for: .touchDown)
        retractOButton.addTarget(self, action: #selector(retractOReleased), for: .touchUpInside)
        retractOButton.addTarget(self, action: #selector(retractOReleased), for: .touchUpOutside)
        retractOButton.isHidden = isJoystickMode
        styleButton(retractOButton)
        view.addSubview(retractOButton)

        // Extend Outer Button
        extendOButton = UIButton(type: .system)
        extendOButton.frame = CGRect(x: view.bounds.midX - 150, y: view.bounds.midY - 180, width: 80, height: 50)
        extendOButton.setTitle("Extend", for: .normal)
        extendOButton.addTarget(self, action: #selector(extendOPressed), for: .touchDown)
        extendOButton.addTarget(self, action: #selector(extendOReleased), for: .touchUpInside)
        extendOButton.addTarget(self, action: #selector(extendOReleased), for: .touchUpOutside)
        extendOButton.isHidden = isJoystickMode
        styleButton(extendOButton)
        view.addSubview(extendOButton)
        
        
        // Create a background view for the Outer buttons
        outerButtonContainer = UIView(frame: CGRect(x: view.bounds.midX - 160, y: view.bounds.midY - 200, width: 100, height: 140))
        outerButtonContainer.backgroundColor = UIColor(white: 0.9, alpha: 0.1)
        outerButtonContainer.layer.cornerRadius = 15
        outerButtonContainer.layer.shadowColor = UIColor.black.cgColor
        outerButtonContainer.layer.shadowOpacity = 0.2
        outerButtonContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        outerButtonContainer.layer.shadowRadius = 4
        view.insertSubview(outerButtonContainer, at:0)
        outerButtonContainer.isHidden = isJoystickMode
        
        // Upper Label
        let upperLabel = UILabel(frame: CGRect(x: 0, y: 0, width: outerButtonContainer.frame.width, height: 20))
        upperLabel.text = "Outer"
        upperLabel.textColor = .darkGray
        upperLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        upperLabel.textAlignment = .center
        outerButtonContainer.addSubview(upperLabel)

        // Reset Button
        resetButton = UIButton(type: .system)
        resetButton.frame = CGRect(x: view.bounds.midX + 70, y: view.bounds.midY - 30, width: 80, height: 50)
        resetButton.setTitle("STOP", for: .normal)
        resetButton.addTarget(self, action: #selector(resetPressed), for: .touchDown)
        resetButton.isHidden = isJoystickMode
        styleButton(resetButton)
        view.addSubview(resetButton)
        
        view.bringSubviewToFront(extendIButton)
        view.bringSubviewToFront(extendOButton)
    }

    func styleButton(_ button: UIButton) {
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.borderWidth = 1.5
        button.layer.cornerRadius = 10
        button.setTitleColor(.systemBlue, for: .normal)
    }

    func setupSmoothToggleButton() {
        smoothToggleButton = UIButton(type: .system)
        smoothToggleButton.frame = CGRect(x: view.bounds.midX - 100, y: view.bounds.midY + 200, width: 200, height: 40)
        smoothToggleButton.setTitle("Smooth Mode", for: .normal)
        smoothToggleButton.addTarget(self, action: #selector(toggleSmoothMode), for: .touchUpInside)
        smoothToggleButton.isHidden = isJoystickMode
        view.addSubview(smoothToggleButton)
    }

    func setupUpperLowerButtons() {
        upperButton = UIButton(type: .system)
        upperButton.frame = CGRect(x: view.bounds.midX + 70, y: view.bounds.midY - 180, width: 80, height: 50)
        upperButton.setTitle("Upper", for: .normal)
        upperButton.addTarget(self, action: #selector(toggleUpper), for: .touchUpInside)
        styleButton(upperButton)
        
        lowerButton = UIButton(type: .system)
        lowerButton.frame = CGRect(x: view.bounds.midX + 70, y: view.bounds.midY - 120, width: 80, height: 50)
        lowerButton.setTitle("Lower", for: .normal)
        lowerButton.addTarget(self, action: #selector(toggleLower), for: .touchUpInside)
        styleButton(lowerButton)
        
        upperButton.isHidden = isJoystickMode
        lowerButton.isHidden = isJoystickMode
        updateUpperLowerButtons()
        
        view.addSubview(upperButton)
        view.addSubview(lowerButton)
    }
    
    // MARK: - Button Actions

    @objc func toggleSmoothMode() {
        isSmoothMode.toggle()
        smoothToggleButton.setTitle(isSmoothMode ? "Smooth Mode" : "Instant Mode", for: .normal)
        sendControlMode(isSmoothMode ? 1 : 0)
    }


    @objc func toggleUpper() {
        upperSelected.toggle()
        if !upperSelected && !lowerSelected {
            lowerSelected = true
        }
        updateUpperLowerButtons()
    }

    @objc func toggleLower() {
        lowerSelected.toggle()
        if !upperSelected && !lowerSelected {
            upperSelected = true
        }
        updateUpperLowerButtons()
    }

    func updateUpperLowerButtons() {
        // Determine value to send
        let valueToSend: Int8
        if upperSelected && lowerSelected {
            valueToSend = 0
        } else if upperSelected {
            valueToSend = 2
        } else {
            valueToSend = 1
        }
        upperButton.backgroundColor = upperSelected ? lightBlue : .clear
        lowerButton.backgroundColor = lowerSelected ? lightBlue : .clear

        
        sendUpperLowerValue(valueToSend)
    }



    @objc func retractIPressed() {
        retractIButton.backgroundColor = lightBlue
        sendExtendInnerValue(-1)
        print("Retract active")
    }

    @objc func retractIReleased() {
        retractIButton.backgroundColor = .clear
        sendExtendInnerValue(0)  // Neutral state when released
        print("Retract inactive")
    }

    @objc func extendIPressed() {
        extendIButton.backgroundColor = lightBlue
        sendExtendInnerValue(1)
        print("Extend active")
    }

    @objc func extendIReleased() {
        extendIButton.backgroundColor = .clear
        sendExtendInnerValue(0)  // Neutral state when released
        print("Extend inactive")
    }
    
    @objc func retractOPressed() {
        retractOButton.backgroundColor = lightBlue
        sendExtendOuterValue(-1)
        print("Retract active")
    }

    @objc func retractOReleased() {
        retractOButton.backgroundColor = .clear
        sendExtendOuterValue(0)  // Neutral state when released
        print("Retract inactive")
    }

    @objc func extendOPressed() {
        extendOButton.backgroundColor = lightBlue
        sendExtendOuterValue(1)
        print("Extend active")
    }

    @objc func extendOReleased() {
        extendOButton.backgroundColor = .clear
        sendExtendOuterValue(0)  // Neutral state when released
        print("Extend inactive")
    }
    
    
    
    @objc func resetPressed() {
        // Reset X and Y values
        resetAll()
        print("Reset to X: 0, Y: 0")
    }

    func resetAll() {
        // Reset sliders to center (value 0.0)
        verticalSlider.value = 0.0
        horizontalSlider.value = 0.0

        // Reset the latest values to 0 as well
        latestXValue = 0.0
        latestYValue = 0.0
        
        extendInner = false
        extendIButton.backgroundColor = .clear
        retractInner = false
        retractIButton.backgroundColor = .clear
        sendControlMode(-1)
        sendJoystickData(xValue: 0, yValue: 0)  // Send zero values immediately
        sendControlMode(isSmoothMode ? 1 : 0)
        updateXYLabel()
    }

    func setupToggleControlButton() {
        controlModeToggleButton = UIButton(type: .system)
        controlModeToggleButton.frame = CGRect(x: view.bounds.width - 120, y: 50, width: 100, height: 30)
        controlModeToggleButton.setTitle("Sliders", for: .normal)
        controlModeToggleButton.addTarget(self, action: #selector(toggleControlMode), for: .touchUpInside)
        view.addSubview(controlModeToggleButton)
    }

    func setupXYLabel() {
        xyLabel = UILabel(frame: CGRect(x: view.bounds.midX - 100, y: 120, width: 200, height: 30))
        xyLabel.textAlignment = .center
        xyLabel.font = UIFont.boldSystemFont(ofSize: 18)
        xyLabel.text = "X: 0.00, Y: 0.00"
        view.addSubview(xyLabel)
    }

    func updateXYLabel() {
        xyLabel.text = String(format: "X: %.2f, Y: %.2f", latestXValue, latestYValue)
    }

    @objc func toggleControlMode() {
        isJoystickMode.toggle()

        // Show/Hide joystick and sliders
        joystick.isHidden = !isJoystickMode
        verticalSlider.isHidden = isJoystickMode
        horizontalSlider.isHidden = isJoystickMode

        // Show/Hide retract, extend, and reset buttons based on mode
        retractIButton.isHidden = isJoystickMode
        extendIButton.isHidden = isJoystickMode
        retractOButton.isHidden = isJoystickMode
        extendOButton.isHidden = isJoystickMode
        resetButton.isHidden = isJoystickMode
        lowerButton.isHidden = isJoystickMode
        upperButton.isHidden = isJoystickMode
        smoothToggleButton.isHidden = isJoystickMode
        innerButtonContainer.isHidden = isJoystickMode
        outerButtonContainer.isHidden = isJoystickMode

        // Update toggle button title
        controlModeToggleButton.setTitle(isJoystickMode ? "Sliders" : "Joystick", for: .normal)


        // Reset all values when changing slides
        resetAll()
    
        sendJoystickData(xValue: 0, yValue: 0)  // Send immediately
    }
    
    @objc func sliderChanged() {
        // Update X and Y values based on slider positions
        latestXValue = CGFloat(horizontalSlider.value)
        latestYValue = CGFloat(verticalSlider.value)
        
        updateXYLabel()  // Update the label with the new X and Y values
        sendJoystickData(xValue: latestXValue, yValue: latestYValue)  // Send immediately
    }

    

    func applyMiddleProgressStyle(for slider: UISlider) {
        let minimumTrackColor = UIColor.blue
        let maximumTrackColor = UIColor.blue.withAlphaComponent(0.3)

        // Set the minimum track color to blue and maximum track color to transparent blue
        slider.minimumTrackTintColor = minimumTrackColor
        slider.maximumTrackTintColor = maximumTrackColor
    }

    @objc func toggleScanMenu() {
        let isMenuOpen = !tableView.isHidden

        tableView.isHidden = isMenuOpen

        // Update scan button title to reflect the current state
        scanButton.setTitle(isMenuOpen ? "Scan" : "Close", for: .normal)

        if !isMenuOpen {
            // Start scanning if the menu is being opened
            startScanning()
        } else {
            // Stop scanning if the menu is being closed
            centralManager.stopScan()
        }
    }
    
    
    @objc func startScanning() {
            if centralManager.state == .poweredOn {
                discoveredPeripherals.removeAll()
                tableView.reloadData()
                centralManager.scanForPeripherals(withServices: nil, options: nil)
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
        // Check if the device has a name and skip unnamed devices
        guard let name = peripheral.name, !name.isEmpty else {
            print("Skipped unnamed device")
            return
        }
        
        print("Discovered: \(name)")

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
                peripheral.discoverCharacteristics(
                    [CBUUID(string: "aaaaaaaa-d2a0-44c8-a271-69ef24094b01"),
                     CBUUID(string: "bbbbbbbb-f0a9-4623-b503-ee7804fca301"),
                     CBUUID(string: "eeeeeee1-313e-4673-af93-844f3cad3e50"),
                     CBUUID(string: "eeeeeee2-313e-4673-af93-844f3cad3e50"),
                     CBUUID(string: "e1a8938e-ddda-4580-9174-d853075f6a19"),
                     CBUUID(string: "09b3299e-3495-4e0f-8274-63bba01432e9"),
                    ], for: service)
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
                print("Discovered characteristic: \(characteristic.uuid.uuidString)")
                if characteristic.uuid == CBUUID(string: "aaaaaaaa-d2a0-44c8-a271-69ef24094b01") {
                    xCharacteristic = characteristic
                    print("X characteristic found")
                } else if characteristic.uuid == CBUUID(string: "bbbbbbbb-f0a9-4623-b503-ee7804fca301") {
                    yCharacteristic = characteristic
                    print("Y characteristic found")
                } else if characteristic.uuid == CBUUID(string: "eeeeeee1-313e-4673-af93-844f3cad3e50") {
                    extendInnerCharacteristic = characteristic
                    print("Extend/Retract inner characteristic found")
                } else if characteristic.uuid == CBUUID(string: "eeeeeee2-313e-4673-af93-844f3cad3e50") {
                    extendOuterCharacteristic = characteristic
                    print("Extend/Retract outer characteristic found")
                } else if characteristic.uuid == CBUUID(string: "e1a8938e-ddda-4580-9174-d853075f6a19") {
                    controlCharacteristic = characteristic
                    print("Extend/Retract outer characteristic found")
                } else if characteristic.uuid == CBUUID(string: "09b3299e-3495-4e0f-8274-63bba01432e9") {
                    stageCharacteristic = characteristic
                    print("Extend/Retract outer characteristic found")
                }
            }
    }
    
    func sendControlMode(_ value: Int8) {
        guard let peripheral = peripheral, let characteristic = controlCharacteristic else { return }
        var valueData = value
        let data = Data(bytes: &valueData, count: MemoryLayout<Int8>.size)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    func sendUpperLowerValue(_ value: Int8) {
        guard let peripheral = peripheral, let characteristic = stageCharacteristic else { return }
        var valueData = value
        let data = Data(bytes: &valueData, count: MemoryLayout<Int8>.size)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    func sendExtendInnerValue(_ value: Int8) {
        guard let peripheral = peripheral, let extendInnerCharacteristic = extendInnerCharacteristic else {
            print("Peripheral or Extend/Retract characteristic is nil.")
            return
        }
        
        // Convert the value to Data and attempt to write to the characteristic
        var valueData = value
        let data = Data(bytes: &valueData, count: MemoryLayout<Int8>.size)
        peripheral.writeValue(data, for: extendInnerCharacteristic, type: .withoutResponse)

        print("Attempted to send Extend/Retract value: \(value)")
    }
    
    func sendExtendOuterValue(_ value: Int8) {
        guard let peripheral = peripheral, let extendOuterCharacteristic = extendOuterCharacteristic else {
            print("Peripheral or Extend/Retract characteristic is nil.")
            return
        }
        
        // Convert the value to Data and attempt to write to the characteristic
        var valueData = value
        let data = Data(bytes: &valueData, count: MemoryLayout<Int8>.size)
        peripheral.writeValue(data, for: extendOuterCharacteristic, type: .withoutResponse)

        print("Attempted to send Extend/Retract value: \(value)")
    }


    func sendJoystickData(xValue: CGFloat, yValue: CGFloat) {
        // Reset the heartbeat timer to delay the next heartbeat
        startHeartbeat()
        
        guard let peripheral = peripheral else { return }

            // Convert joystick values to Int16 (range -255 to 255)
            let xIntValue = Int16(xValue * 255)
            let yIntValue = Int16(yValue * 255)

            // Send X and Y data immediately
        if let xCharacteristic = xCharacteristic, let yCharacteristic = yCharacteristic {
            var xData = xIntValue
            var yData = yIntValue
            let xDataBytes = Data(bytes: &xData, count: MemoryLayout<Int16>.size)
            let yDataBytes = Data(bytes: &yData, count: MemoryLayout<Int16>.size)
            
            // Write data without queuing or waiting for acknowledgments
            peripheral.writeValue(xDataBytes, for: xCharacteristic, type: .withoutResponse)
            peripheral.writeValue(yDataBytes, for: yCharacteristic, type: .withoutResponse)
            
            print("Sent X data: \(xIntValue), Y data: \(yIntValue)")
        }
    }
}

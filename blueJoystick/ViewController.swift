import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource {

    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var peripheral: CBPeripheral?
    
    var xCharacteristic: CBCharacteristic?
    var yCharacteristic: CBCharacteristic?

    var tableView: UITableView!
    
    let sendInterval: TimeInterval = 0.5
    var sendTimer: Timer?

    var latestXValue: CGFloat = 0.0
    var latestYValue: CGFloat = 0.0

    // UI elements
    var joystick: JoystickView!
    var verticalSlider: UISlider!
    var horizontalSlider: UISlider!
    var controlModeToggleButton: UIButton!
    var isJoystickMode = true  // Keeps track of current mode (joystick or sliders)
    var xyLabel: UILabel!  // Label to display current X and Y values

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize Bluetooth CentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Add Scan Button
        let scanButton = UIButton(type: .system)
        scanButton.frame = CGRect(x: 20, y: 50, width: 100, height: 30)
        scanButton.setTitle("Scan", for: .normal)
        scanButton.addTarget(self, action: #selector(startScanning), for: .touchUpInside)
        view.addSubview(scanButton)

        // TableView for Bluetooth devices
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isHidden = true
        view.addSubview(tableView)

        // Setup joystick
        setupJoystick()

        // Setup sliders
        setupSliders()

        // Toggle button for switching between joystick and sliders
        setupToggleControlButton()

        // Setup label to display current X and Y values
        setupXYLabel()

        // Start the timer to send joystick/slider data at intervals
        startSendTimer()
    }

    func setupJoystick() {
        let joystickSize: CGFloat = 200
        joystick = JoystickView(frame: CGRect(x: 0, y: 0, width: joystickSize, height: joystickSize))
        joystick.center = view.center
        joystick.joystickMoved = { [weak self] (xValue, yValue) in
            self?.latestXValue = xValue
            self?.latestYValue = -yValue
            self?.updateXYLabel()  // Update the X and Y values on the screen
        }
        view.addSubview(joystick)
    }

    func setupSliders() {
        let sliderLength: CGFloat = 300

        // Vertical Slider (extended)
        verticalSlider = UISlider(frame: CGRect(x: view.bounds.midX - 150, y: view.bounds.midY - sliderLength / 1.5, width: sliderLength, height: sliderLength / 2)) // Extended length
        verticalSlider.minimumValue = -1.0
        verticalSlider.maximumValue = 1.0
        verticalSlider.value = 0.0
        verticalSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))  // Rotate to vertical
        verticalSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        verticalSlider.isContinuous = true
        verticalSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)  // Set thumb image for consistency
        verticalSlider.isHidden = true
        view.addSubview(verticalSlider)

        // Horizontal Slider
        horizontalSlider = UISlider(frame: CGRect(x: view.bounds.midX - sliderLength / 2, y: view.bounds.midY + 100, width: sliderLength, height: 40))
        horizontalSlider.minimumValue = -1.0
        horizontalSlider.maximumValue = 1.0
        horizontalSlider.value = 0.0
        horizontalSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        horizontalSlider.isContinuous = true
        horizontalSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)  // Set thumb image for consistency
        horizontalSlider.isHidden = true
        view.addSubview(horizontalSlider)

        // Apply the middle progress color from the middle
        applyMiddleProgressStyle(for: verticalSlider)
        applyMiddleProgressStyle(for: horizontalSlider)
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

        // Switch between joystick and sliders
        if isJoystickMode {
            controlModeToggleButton.setTitle("Sliders", for: .normal)
            joystick.isHidden = false
            verticalSlider.isHidden = true
            horizontalSlider.isHidden = true
        } else {
            controlModeToggleButton.setTitle("Joystick", for: .normal)
            joystick.isHidden = true
            verticalSlider.isHidden = false
            horizontalSlider.isHidden = false

            // Reset sliders to center when mode is switched to sliders
            resetSliders()
        }
    }

    @objc func sliderChanged() {
        // Update X and Y values based on slider positions
        latestXValue = CGFloat(horizontalSlider.value)
        latestYValue = CGFloat(verticalSlider.value)

        updateXYLabel()  // Update the label with the new X and Y values
    }

    func resetSliders() {
        // Reset sliders to center (value 0.0)
        verticalSlider.value = 0.0
        horizontalSlider.value = 0.0

        // Reset the latest values to 0 as well
        latestXValue = 0.0
        latestYValue = 0.0

        updateXYLabel()
    }

    func applyMiddleProgressStyle(for slider: UISlider) {
        let minimumTrackColor = UIColor.blue
        let maximumTrackColor = UIColor.blue.withAlphaComponent(0.3)

        // Set the minimum track color to blue and maximum track color to transparent blue
        slider.minimumTrackTintColor = minimumTrackColor
        slider.maximumTrackTintColor = maximumTrackColor
    }

    func startSendTimer() {
        sendTimer = Timer.scheduledTimer(timeInterval: sendInterval, target: self, selector: #selector(sendCurrentJoystickData), userInfo: nil, repeats: true)
    }

    @objc func sendCurrentJoystickData() {
        sendJoystickData(xValue: latestXValue, yValue: latestYValue)
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

        // Convert joystick values to Int16 (-127 to 127)
        let xIntValue = Int8(xValue * 127)
        let yIntValue = Int8(yValue * 127)

        // Send X value as Int16 (2 bytes)
        if let xCharacteristic = xCharacteristic {
            var xData = xIntValue
            let xDataBytes = Data(bytes: &xData, count: MemoryLayout<Int8>.size)
            peripheral.writeValue(xDataBytes, for: xCharacteristic, type: .withResponse)
            print("Sent X data: \(xIntValue)")
        }

        // Send Y value as Int16 (2 bytes)
        if let yCharacteristic = yCharacteristic {
            var yData = yIntValue
            let yDataBytes = Data(bytes: &yData, count: MemoryLayout<Int8>.size)
            peripheral.writeValue(yDataBytes, for: yCharacteristic, type: .withResponse)
            print("Sent Y data: \(yIntValue)")
        }
    }

}

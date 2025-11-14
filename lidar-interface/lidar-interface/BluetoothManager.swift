//
//  BluetoothManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/19/25.
//

import CoreBluetooth

@Observable
class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    
    // minimum RSSI value allowed for the device to be discoverable
    let MIN_RSSI = -60
    
    let WHV_SRV_UUID = CBUUID(string: "8b322909-2d3b-447b-a4d5-dfe0c009ec5a")
    let WHV_CHAR_UUID = CBUUID(string: "8b32290a-2d3b-447b-a4d5-dfe0c009ec5a")
    
    var state: CBManagerState?
    var scanning = false
    var connecting = false
    var discoveredDevices: [CBPeripheral] = []
    var connectedDevice: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        state = centralManager.state
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        stopScanning()
        connecting = true
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnectFromDevice() {
        guard let peripheral = connectedDevice else {
            print("No peripheral connected")
            return
        }
        
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            discoveredDevices.removeAll()
            scanning = true
            centralManager.scanForPeripherals(withServices: [WHV_SRV_UUID])
        }
    }
    
    func stopScanning() {
        if scanning {
            centralManager.stopScan()
        }
        
        scanning = false
    }
    
    func sendData(_ data: Data) {
        guard let peripheral = connectedDevice, let characteristic = writeCharacteristic else {
            return
        }
        
        print("Sending data \(data) to characteristic \(characteristic.uuid)... we are ion state \(peripheral.state)")
        
        if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let discoveredDevice = discoveredDevices.first(where: { $0.identifier == peripheral.identifier })
        if MIN_RSSI > RSSI.intValue {
            if discoveredDevice != nil {
                discoveredDevices.removeAll(where: { $0.identifier == peripheral.identifier })
            }
            return
        }
        
        if discoveredDevice == nil {
            discoveredDevices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, _ peripheral: CBPeripheral, _: Error?) {
        connectedDevice = nil
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScanning()
        peripheral.delegate = self
        peripheral.discoverServices([WHV_SRV_UUID])
        connectedDevice = peripheral
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let peripheralServices = peripheral.services else { return }
        guard let service = peripheralServices.first(where: { $0.uuid.isEqual(WHV_SRV_UUID) }) else { return }
        
        peripheral.discoverCharacteristics([WHV_CHAR_UUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(WHV_CHAR_UUID) {
                writeCharacteristic = characteristic
            }
        }
        
        connecting = false
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = centralManager.state
    }
}

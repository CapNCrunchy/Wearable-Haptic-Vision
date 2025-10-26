//
//  BluetoothManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 10/19/25.
//

import CoreBluetooth

@Observable
class BluetoothManager: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager!
    
    // minimum RSSI value allowed for the device to be discoverable
    let MIN_RSSI = -60
    
    let WHV_SRV_UUID = CBUUID(string: "8b322909-2d3b-447b-a4d5-dfe0c009ec5a")
    
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
    }
    
    func sendData(_ data: Data) {
        guard let peripheral = connectedDevice, let characteristic = writeCharacteristic else {
            return
        }
        
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
        connectedDevice = peripheral
        connecting = false
    }
    
    func centralManager(_ central: CBCentralManager, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = centralManager.state
    }
}

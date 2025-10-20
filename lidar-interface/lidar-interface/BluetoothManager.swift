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
    let MIN_RSSI = -50
    
    var state: CBManagerState?
    var scanning = false
    var discoveredDevices: [CBPeripheral] = []
    var connectedDevice: CBPeripheral?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        state = centralManager.state
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            discoveredDevices.removeAll()
            scanning = true
            centralManager.scanForPeripherals(withServices: nil) // TODO: only scan for peripherals that have a CBUUID specific to the haptic feedback controller
        }
    }
    
    func stopScanning() {
        if scanning {
            centralManager.stopScan()
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
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = centralManager.state
    }
}

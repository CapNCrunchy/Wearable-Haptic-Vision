//
//  BLEDeviceManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import CoreBluetooth

class BLEDeviceManager: NSObject, DeviceManager, CBCentralManagerDelegate {
    var discoveredDevices: [Device] = []
    var connectedDevice: Device? = nil
    var scanning: Bool = false
    
    private var centralManager: CBCentralManager!
    private var managerState: CBManagerState = .unknown
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        managerState = centralManager.state
    }
    
    func discoverDevices() {
        if managerState == .poweredOn {
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
    
    func connectDevice(_ device: any Device) {
        stopScanning()
        device.setConnection(.connecting)
        
        if let bleDevice = device as? BLEDevice {
            centralManager.connect(bleDevice.peripheral, options: nil)
        }
    }
    
    func disconnectDevice() {
        if let bleDevice = connectedDevice as? BLEDevice {
            centralManager.cancelPeripheralConnection(bleDevice.peripheral)
        }
    }
    
    func disconnectAndRemoveDevice() {
        if connectedDevice?.connection == .connected {
            disconnectDevice()
        }
        
        connectedDevice = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let discoveredDevice = discoveredDevices.first(where: { $0.id == peripheral.identifier.uuidString })
        if MIN_RSSI > RSSI.intValue {
            if discoveredDevice != nil {
                discoveredDevices.removeAll(where: { $0.id == peripheral.identifier.uuidString })
            }
            return
        }
        
        if discoveredDevice == nil {
            discoveredDevices.append(BLEDevice(peripheral: peripheral))
        }
    }
    
    func centralManager(_ central: CBCentralManager, _ peripheral: CBPeripheral, _: Error?) {
        connectedDevice = nil
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScanning()
        connectedDevice = BLEDevice(peripheral: peripheral)
        // we know that connectedDevice is a BLEDevice as we just set it
        peripheral.delegate = connectedDevice as! BLEDevice
        peripheral.discoverServices([WHV_SRV_UUID])
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        managerState = centralManager.state
    }
}

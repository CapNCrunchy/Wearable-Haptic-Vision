//
//  BLEDeviceManager.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import CoreBluetooth
import Combine
import AVFoundation

class BLEDeviceManager: NSObject, DeviceManager, CBCentralManagerDelegate, ObservableObject {
    @Published var discoveredDevices: [Device] = []
    @Published var connectedDevice: Device? = nil
    @Published var scanning: Bool = false
    
    private var centralManager: CBCentralManager!
    private var managerState: CBManagerState = .unknown
    
    // Persistent storage key for paired device
    private let pairedDeviceKey = "whv.lidar.pairedDeviceUUID"
    
    private let autoReconnectEnabled = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        managerState = centralManager.state
    }

    private func savePairedDevice(_ uuid: UUID) {
        UserDefaults.standard.set(uuid.uuidString, forKey: pairedDeviceKey)
    }
    
    private func retrievePairedDeviceUUID() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: pairedDeviceKey) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    private func clearPairedDevice() {
        UserDefaults.standard.removeObject(forKey: pairedDeviceKey)
    }
    
    func reconnectToPairedDevice() {
        guard managerState == .poweredOn else { return }
        guard let pairedUUID = retrievePairedDeviceUUID() else { return }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [pairedUUID])
        
        if let peripheral = peripherals.first {
            let device = BLEDevice(peripheral: peripheral)
            connectedDevice = device
            
            if peripheral.state == .connected {
                device.setConnection(.connected)
                peripheral.delegate = device
                peripheral.discoverServices([WHV_SRV_UUID])
            } else {
                connectDevice(device)
            }
        } else {
            clearPairedDevice()
        }
    }
    
    private func restorePairedDevice() {
        guard managerState == .poweredOn else { return }
        guard let pairedUUID = retrievePairedDeviceUUID() else { return }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [pairedUUID])
        
        if let peripheral = peripherals.first {
            let device = BLEDevice(peripheral: peripheral)
            connectedDevice = device
            
            if peripheral.state == .connected {
                device.setConnection(.connected)
                peripheral.delegate = device
                peripheral.discoverServices([WHV_SRV_UUID])
            } else {
                device.setConnection(.disconnected)
            }
        } else {
            clearPairedDevice()
        }
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
        
        TTSService.shared.announceDeviceConnecting(name: device.name)
        
        if let bleDevice = device as? BLEDevice {
            centralManager.connect(bleDevice.peripheral, options: nil)
        }
    }
    
    func disconnectDevice() {
        TTSService.shared.announceDeviceDisconnected()
        
        if let bleDevice = connectedDevice as? BLEDevice {
            bleDevice.setConnection(.disconnecting)
            centralManager.cancelPeripheralConnection(bleDevice.peripheral)
        }
    }
    
    func disconnectAndRemoveDevice() {
        if let connection = connectedDevice?.connection,
           connection == .connected || connection == .connecting {
            if let bleDevice = connectedDevice as? BLEDevice {
                bleDevice.setConnection(.disconnecting)
                centralManager.cancelPeripheralConnection(bleDevice.peripheral)
            }
        }
        
        clearPairedDevice()
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
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let bleDevice = connectedDevice as? BLEDevice,
           bleDevice.peripheral.identifier == peripheral.identifier {
            bleDevice.setConnection(.disconnected)
        }
        connectedDevice = nil
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScanning()
        connectedDevice = BLEDevice(peripheral: peripheral)
        // we know that connectedDevice is a BLEDevice as we just set it
        peripheral.delegate = connectedDevice as! BLEDevice
        peripheral.discoverServices([WHV_SRV_UUID])
        
        savePairedDevice(peripheral.identifier)
        
        TTSService.shared.announceDeviceConnected(name: peripheral.name ?? "Device")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let bleDevice = connectedDevice as? BLEDevice,
           bleDevice.peripheral.identifier == peripheral.identifier {
            bleDevice.setConnection(.disconnected)
            // Force the device manager to notify observers about the state change
            self.objectWillChange.send()
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        managerState = centralManager.state
        
        if managerState == .poweredOn {
            if autoReconnectEnabled {
                reconnectToPairedDevice()
            } else {
                restorePairedDevice()
            }
        }
    }
}

//
//  BLEDevice.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import CoreBluetooth

class BLEDevice: NSObject, Device, CBPeripheralDelegate {
    var id: String
    
    var name: String
    var connection: DeviceConnection
    
    var peripheral: CBPeripheral
    private var writeCharacteristic: CBCharacteristic?
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.id = peripheral.identifier.uuidString
        self.name = peripheral.name ?? "Unknown Device"
        self.connection = peripheral.state == .connected ? .connected : .disconnected
    }
    
    func setConnection(_ connection: DeviceConnection) {
        self.connection = connection
    }
    
    func sendData(_ data: Data) {
        guard let characteristic = writeCharacteristic else {
            return
        }
        
        if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
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
        
        setConnection(.connected)
    }
}

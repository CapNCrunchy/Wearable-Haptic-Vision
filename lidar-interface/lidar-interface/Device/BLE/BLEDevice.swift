//
//  BLEDevice.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import CoreBluetooth
import Combine

class BLEDevice: NSObject, Device, CBPeripheralDelegate, ObservableObject {
    var id: String
    
    var name: String
    @Published var connection: DeviceConnection
    
    var peripheral: CBPeripheral
    private var writeCharacteristic: CBCharacteristic?
    private var isWriting: Bool = false
    private var writeQueue: [Data] = []
    
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
        
        // If using .withResponse, queue writes to prevent overwhelming BLE
        if characteristic.properties.contains(.write) {
            writeQueue.append(data)
            processWriteQueue()
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            // Check if peripheral can accept more data
            if peripheral.canSendWriteWithoutResponse {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            } else {
                writeQueue.append(data)
            }
        }
    }
    
    private func processWriteQueue() {
        guard let characteristic = writeCharacteristic else { return }
        guard !isWriting, !writeQueue.isEmpty else { return }
        
        let data = writeQueue.removeFirst()
        isWriting = true
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
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
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        isWriting = false
        processWriteQueue()
    }
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard let characteristic = writeCharacteristic,
              characteristic.properties.contains(.writeWithoutResponse),
              !writeQueue.isEmpty else { return }
        
        let data = writeQueue.removeFirst()
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }
}

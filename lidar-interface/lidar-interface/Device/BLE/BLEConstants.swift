//
//  BLEConstants.swift
//  lidar-interface
//
//  Created by Colin McClure on 1/30/26.
//

import CoreBluetooth

// minimum RSSI value allowed for the device to be discoverable
let MIN_RSSI = -60

let WHV_SRV_UUID = CBUUID(string: "8b322909-2d3b-447b-a4d5-dfe0c009ec5a")
let WHV_CHAR_UUID = CBUUID(string: "8b32290a-2d3b-447b-a4d5-dfe0c009ec5a")

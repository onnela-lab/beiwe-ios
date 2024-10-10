//
//  BluetoothManager.swift
//  Beiwe
//
//  Created by Babtista, Reyva on 10/9/24.
//  Copyright © 2024 Reyva Babtista. All rights reserved.
//

import CoreBluetooth

let bluetooth_headers = [
    "timestamp",
    "hashed MAC",
    "RSSI",
]

struct BluetoothDataPoint {
    var timestamp: TimeInterval
    var hashedMAC: String
    var RSSI: String
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, DataServiceProtocol {
    var bluetoothManager: CBCentralManager?
    let storeType = "bt"
    var dataStorage: DataStorage?
    var datapoints = [BluetoothDataPoint]()
    var offsetSince1970: Double = 0
    var currentCBState: CBManagerState?
    let cacheLock = NSLock()
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.currentCBState = central.state
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let data = BluetoothDataPoint(
            timestamp: Date().timeIntervalSince1970 * 1000,
            hashedMAC: peripheral.identifier.uuidString,
            RSSI: RSSI.stringValue
        )
        self.cacheLock.lock()
        self.datapoints.append(data)
        self.cacheLock.unlock()
        
        if self.datapoints.count > BLUETOOTH_CACHE_SIZE {
            self.flush()
        }
    }
    
    func initCollecting() -> Bool {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: bluetooth_headers)
        self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil)
        self.offsetSince1970 = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        return true
    }
    
    func startCollecting() {
        guard let state = self.currentCBState, state == CBManagerState.poweredOn else {
            // do something about turning on bluetooth?
            return
        }
        
        bluetoothManager?.scanForPeripherals(withServices: nil, options: ["CBCentralManagerScanOptionAllowDuplicatesKey": false])
        AppEventManager.sharedInstance.logAppEvent(event: "bt_on", msg: "Bluetooth scanning on")
    }
    
    func pauseCollecting() {
        guard let state = self.currentCBState, state == CBManagerState.poweredOn else {
            // do something about turning on bluetooth?
            return
        }
        
        bluetoothManager?.stopScan()
        AppEventManager.sharedInstance.logAppEvent(event: "bt_off", msg: "Bluetooth scanning off")
    }
    
    func finishCollecting() {
        self.pauseCollecting()
        self.createNewFile()
    }
    
    func createNewFile() {
        self.flush()
        self.dataStorage?.reset()
    }
    
    func flush() {
        self.cacheLock.lock()
        let data_to_write = self.datapoints
        self.datapoints = []
        self.cacheLock.unlock()
        for data in data_to_write {
            self.dataStorage?.store([
                String(Int64(data.timestamp)),
                data.hashedMAC,
                data.RSSI
            ])
        }
    }
    
    
}

//
//  OmniringManager.swift
//  Beiwe
//
//  Created by Babtista, Reyva on 10/10/24.
//  Copyright © 2024 Rocketfarm Studios. All rights reserved.
//

import CoreBluetooth

private let omniring_headers = [
    "timestamp",
    "hashed MAC",
    "RSSI",
]

private struct OmniringDataPoint {
    var timestamp: TimeInterval
    var hashedMAC: String
    var RSSI: String
}

class OmniringManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, DataServiceProtocol {
    private var bluetoothManager: CBCentralManager?
    private let storeType = "omniring"
    private var dataStorage: DataStorage?
    private var datapoints = [OmniringDataPoint]()
    private var currentCBState: CBManagerState?
    private let cacheLock = NSLock()
    private var collecting = false
    private var omniringPeripheral: CBPeripheral?
    private let omniringDataCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    private var omniringDataCharacteristic: CBCharacteristic?
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.currentCBState = central.state
        self.bluetoothManager?.scanForPeripherals(withServices: nil, options: ["CBCentralManagerScanOptionAllowDuplicatesKey": false])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        self.omniringPeripheral = nil
        self.omniringDataCharacteristic = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        guard let characteristics = service.characteristics else {
            return
        }
        
        for char in characteristics {
            print("characteristic \(char) found")
            if char.uuid.uuidString.lowercased() == self.omniringDataCharacteristicUUID {
                self.omniringDataCharacteristic = char
                self.omniringPeripheral?.setNotifyValue(self.collecting, for: self.omniringDataCharacteristic!)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            print("service \(service) found")
            print("discovering characteristics for service..")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to omniring \(peripheral.name ?? "")")
        print("now discovering services..")
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("failed to connect to omniring \(peripheral.name ?? "")")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (peripheral.name ?? "").starts(with: "PPG_Ring") {
            self.omniringPeripheral = peripheral
            self.omniringPeripheral?.delegate = self
            central.connect(self.omniringPeripheral!)
        }
    }
    
    func initCollecting() -> Bool {
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: omniring_headers)
        self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil)
        return true
    }
    
    func startCollecting() {
        guard let state = self.currentCBState, state == CBManagerState.poweredOn else {
            self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil)
            return
        }
        
        self.collecting = true
        if self.omniringDataCharacteristic != nil {
            self.omniringPeripheral?.setNotifyValue(self.collecting, for: self.omniringDataCharacteristic!)
        }
        AppEventManager.sharedInstance.logAppEvent(event: "omniring_on", msg: "Omniring collection on")
    }
    
    func pauseCollecting() {
        self.collecting = false
        if self.omniringDataCharacteristic != nil {
            self.omniringPeripheral?.setNotifyValue(self.collecting, for: self.omniringDataCharacteristic!)
        }
        AppEventManager.sharedInstance.logAppEvent(event: "omniring_off", msg: "Omniring collection off")
    }
    
    func finishCollecting() {
        self.pauseCollecting()
        if self.omniringPeripheral != nil {
            self.bluetoothManager?.cancelPeripheralConnection(self.omniringPeripheral!)
        }
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

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
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.currentCBState = central.state
        self.bluetoothManager?.scanForPeripherals(withServices: nil, options: ["CBCentralManagerScanOptionAllowDuplicatesKey": false])
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
        self.collecting = true
        AppEventManager.sharedInstance.logAppEvent(event: "omniring_on", msg: "Omniring collection on")
    }
    
    func pauseCollecting() {
        guard let state = self.currentCBState, state == CBManagerState.poweredOn else {
            // do something about turning on bluetooth?
            return
        }
        
        self.bluetoothManager?.stopScan()
        self.collecting = false
        AppEventManager.sharedInstance.logAppEvent(event: "omniring_off", msg: "Omniring collection off")
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

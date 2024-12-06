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
    "PPG_red",
    "PPG_IR",
    "PPG_Green",
    "IMU_Accel_x",
    "IMU_Accel_y",
    "IMU_Accel_z",
    "IMU_Gyro_x",
    "IMU_Gyro_y",
    "IMU_Gyro_z",
    "IMU_Mag_x",
    "IMU_Mag_y",
    "IMU_Mag_z",
    "temperature",
    "timestamp"
]

private struct OmniringDataPoint {
    var timestamp: String
    var ppgRed: String
    var ppgIR: String
    var ppgGreen: String
    var imuAccelX: String
    var imuAccelY: String
    var imuAccelZ: String
    var imuGyroX: String
    var imuGyroY: String
    var imuGyroZ: String
    var imuMagX: String
    var imuMagY: String
    var imuMagZ: String
    var temperature: String
    var ringTimestamp: String
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

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if characteristic.uuid.uuidString.lowercased() == self.omniringDataCharacteristicUUID && self.collecting {
            self.captureData(raw: characteristic.value)
        }
    }
    
    func captureData(raw: Data?) {
        let generated = decodeByteData(raw)
        let data = OmniringDataPoint(
            timestamp: String(Int64(Date().timeIntervalSince1970 * 1000)),
            ppgRed: String(generated[0]),
            ppgIR: String(generated[1]),
            ppgGreen: String(generated[2]),
            imuAccelX: String(generated[3]),
            imuAccelY: String(generated[4]),
            imuAccelZ: String(generated[5]),
            imuGyroX: String(generated[6]),
            imuGyroY: String(generated[7]),
            imuGyroZ: String(generated[8]),
            imuMagX: String(generated[9]),
            imuMagY: String(generated[10]),
            imuMagZ: String(generated[11]),
            temperature: String(generated[12]),
            ringTimestamp: String(Int64(generated[13]))
        )
        self.cacheLock.lock()
        self.datapoints.append(data)
        self.cacheLock.unlock()
        
        if self.datapoints.count > OMNIRING_CACHE_SIZE {
            self.createNewFile()
        }
    }
    
    func unpackFloatFromByteArray(_ byteArray: [UInt8]) -> Float {
        let data = Data(byteArray)
        return data.withUnsafeBytes { $0.load(as: Float.self) }
    }
    
    func decodeByteData(_ byteData: Data?) -> [Float] {
        if byteData == nil {
            return []
        }
        
        var floatArray: [Float] = []
        
        for i in stride(from: 0, to: byteData!.count, by: 4) {
            let byteSlice = Array(byteData![i..<i+4])
            let tmpFloat = unpackFloatFromByteArray(byteSlice)
            floatArray.append(tmpFloat)
        }
        
        return floatArray
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
        print("discovered \(peripheral.name ?? "")")
        if (peripheral.name ?? "").starts(with: "OmniRing") {
            self.omniringPeripheral = peripheral
            self.omniringPeripheral?.delegate = self
            central.connect(self.omniringPeripheral!)
        }
    }
    
    func initCollecting() -> Bool {
        print("init omniring")
        self.dataStorage = DataStorageManager.sharedInstance.createStore(self.storeType, headers: omniring_headers)
        self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil)
        return true
    }
    
    func startCollecting() {
        guard let state = self.currentCBState, state == CBManagerState.poweredOn else {
            self.bluetoothManager = CBCentralManager.init(delegate: self, queue: nil)
            return
        }
        
        if self.omniringPeripheral == nil {
            self.bluetoothManager?.scanForPeripherals(withServices: nil)
        } else if self.omniringDataCharacteristic != nil {
            print("start omniring")
            self.collecting = true
            self.omniringPeripheral?.setNotifyValue(self.collecting, for: self.omniringDataCharacteristic!)
            AppEventManager.sharedInstance.logAppEvent(event: "omniring_on", msg: "Omniring collection on")
        } else {
            print("omniring characteristic not found, pausing data collection..")
            self.pauseCollecting()
        }
    }
    
    func pauseCollecting() {
        print("pause omniring")
        self.collecting = false
        if self.omniringDataCharacteristic != nil {
            self.omniringPeripheral?.setNotifyValue(self.collecting, for: self.omniringDataCharacteristic!)
        }
        AppEventManager.sharedInstance.logAppEvent(event: "omniring_off", msg: "Omniring collection off")
    }
    
    func finishCollecting() {
        print("finish omniring")
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
                data.timestamp,
                data.ppgRed,
                data.ppgIR,
                data.ppgGreen,
                data.imuAccelX,
                data.imuAccelY,
                data.imuAccelZ,
                data.imuGyroX,
                data.imuGyroY,
                data.imuGyroZ,
                data.imuMagX,
                data.imuMagY,
                data.imuMagZ,
                data.temperature,
                data.ringTimestamp
            ])
        }
    }
}

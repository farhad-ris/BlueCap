//
//  Mocks.swift
//  BlueCapKit
//
//  Created by Troy Stribling on 5/2/15.
//  Copyright (c) 2015 Troy Stribling. The MIT License (MIT).
//

import UIKit
import CoreBluetooth
import CoreLocation
import BlueCapKit

struct TestFailure {
    static let error = NSError(domain:"BlueCapKit Tests", code:100, userInfo:[NSLocalizedDescriptionKey:"Testing"])
}

let peripheralAdvertisements = [CBAdvertisementDataLocalNameKey:"Test Peripheral",
                                CBAdvertisementDataTxPowerLevelKey:NSNumber(integer:-45)]

class CBCentralManagerMock : CBCentralManagerWrappable {
    
    var state : CBCentralManagerState
    var scanForPeripheralsWithServicesCalled = false
    var stopScanCalled = false
    
    init(state:CBCentralManagerState = .PoweredOn) {
        self.state = state
    }
    
    func scanForPeripheralsWithServices(uuids:[CBUUID]?, options:[String:AnyObject]?) {
        self.scanForPeripheralsWithServicesCalled = true
    }
    
    func stopScan() {
        self.stopScanCalled = true
    }
    
    func connectPeripheral(peripheral:CBPeripheral, options:[String:AnyObject]?) {
    }
    
    func cancelPeripheralConnection(peripheral:CBPeripheral) {
        
    }
    
}

class CBPeripheralMock : CBPeripheralWrappable {
   
    var _delegate : CBPeripheralDelegate? = nil
    var state : CBPeripheralState
    
    var setDelegateCalled = false
    
    let identifier = NSUUID()

    init(state:CBPeripheralState = .Disconnected) {
        self.state = state
    }
    
    var delegate : CBPeripheralDelegate? {
        get {
            return self._delegate
        }
        set {
            self._delegate = newValue
            self.setDelegateCalled = self._delegate == nil ? false : true
        }
    }
    
    var name : String? {
        return "Test Peripheral"
    }

    var services : [CBService]? {
        return nil
    }
    
    func discoverServices(services:[CBUUID]?) {
        
    }
    
    func discoverCharacteristics(characteristics:[CBUUID]?, forService:CBService) {
        
    }
    
    func setNotifyValue(state:Bool, forCharacteristic:CBCharacteristic) {
        
    }
    
    func readValueForCharacteristic(characteristic:CBCharacteristic) {
        
    }
    
    func writeValue(data:NSData, forCharacteristic:CBCharacteristic, type:CBCharacteristicWriteType) {
        
    }

}

//
//struct ServiceMockValues {
//    static var error : NSError? = nil
//}
//
//struct ServiceMock : ServiceWrappable {
//    
//    let uuid  : CBUUID
//    let name  : String
//    let state : CBPeripheralState
//    
//    let impl = ServiceImpl<ServiceMock>()
//    
//    init(uuid:CBUUID = CBUUID(string:"2f0a0017-69aa-f316-3e78-4194989a6ccc"),
//         name:String = "Mock",
//         state:CBPeripheralState = .Connected) {
//        self.uuid = uuid
//        self.name = name
//        self.state = state
//    }
//    
//    func discoverCharacteristics(characteristics:[CBUUID]?) {
//    }
//    
//    func didDiscoverCharacteristics(error:NSError?) {
//        CentralQueue.async {
//            self.impl.didDiscoverCharacteristics(self, error:ServiceMockValues.error)
//        }
//    }
//    
//    func createCharacteristics() {
//    }
//    
//    func discoverAllCharacteristics() -> Future<ServiceMock> {
//        let future = self.impl.discoverIfConnected(self, characteristics:nil)
//        self.didDiscoverCharacteristics(ServiceMockValues.error)
//        return future
//    }
//    
//}
//
//final class CharacteristicMock : CharacteristicWrappable {
//    
//    var _isNotifying             = false
//    var _stringValues            = [String]()
//    var _propertyEnabled         = true
//    var _stringValue             = ["Mock":"1"]
//    var _dataFromStringValue     = "01".dataFromHexString()
//    var _afterDiscoveredPromise  = StreamPromise<CharacteristicMock>()
//    
//    let impl = CharacteristicImpl<CharacteristicMock>()
//    
//    var uuid : CBUUID {
//        return CBUUID(string:"2f0a0017-69aa-f316-3e78-4194989a6c1a")
//    }
//    
//    init (propertyEnabled:Bool = true) {
//        self._propertyEnabled = propertyEnabled
//    }
//    
//    var name : String {
//        return "Mock"
//    }
//    
//    var isNotifying : Bool {
//        return self._isNotifying
//    }
//    
//    var stringValues : [String] {
//        return self._stringValues
//    }
//    
//    var afterDiscoveredPromise  : StreamPromise<CharacteristicMock>? {
//        return self._afterDiscoveredPromise
//    }
//    
//    func stringValue(data:NSData?) -> [String:String]? {
//        return self._stringValue
//    }
//    
//    func dataFromStringValue(stringValue:[String:String]) -> NSData? {
//        return self._dataFromStringValue
//    }
//    
//    func setNotifyValue(state:Bool) {
//        self._isNotifying = state
//    }
//    
//    func propertyEnabled(property:CBCharacteristicProperties) -> Bool {
//        return self._propertyEnabled
//    }
//    
//    func readValueForCharacteristic() {
//    }
//    
//    func writeValue(value:NSData) {
//    }
//}
//
//class TimedScanneratorMock : TimedScanneratorWrappable {
//    
//    let impl = TimedScanneratorImpl<TimedScanneratorMock>()
//    
//    var promise     = StreamPromise<PeripheralMock>()
//    var _perpherals : [PeripheralMock]
//    
//    var peripherals : [PeripheralMock] {
//        return self._perpherals
//    }
//    
//    init(peripherals:[PeripheralMock] = [PeripheralMock]()) {
//        self._perpherals = peripherals
//    }
//    
//    func startScanning(capacity:Int?) -> FutureStream<PeripheralMock> {
//        return self.startScanningForServiceUUIDs(nil, capacity:capacity)
//    }
//    
//    func startScanningForServiceUUIDs(uuids:[CBUUID]!, capacity:Int?) -> FutureStream<PeripheralMock> {
//        return self.promise.future
//    }
//    
//    func wrappedStopScanning() {
//    }
//    
//    func timeout() {
//        self.promise.failure(BCError.peripheralDiscoveryTimeout)
//    }
//    
//    func didDiscoverPeripheral(peripheral:PeripheralMock) {
//        self._perpherals.append(peripheral)
//        self.promise.success(peripheral)
//    }
//    
//}


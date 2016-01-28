//
//  PeripheralManager.swift
//  BlueCap
//
//  Created by Troy Stribling on 8/9/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import Foundation
import CoreBluetooth

// MARK: - CBPeripheralManagerInjectable -
public protocol CBPeripheralManagerInjectable {
    var isAdvertising: Bool                 { get }
    var state: CBPeripheralManagerState     { get }
    
    func startAdvertising(advertisementData:[String:AnyObject]?)
    func stopAdvertising()
    func addService(service: CBMutableService)
    func removeService(service: CBMutableService)
    func removeAllServices()
    func respondToRequest(request: CBATTRequest, withResult result: CBATTError)
    func updateValue(value: NSData, forCharacteristic characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool
}

extension CBPeripheralManager : CBPeripheralManagerInjectable {}

// MARK: - CBATTRequestInjectable -
public protocol CBATTRequestInjectable {
    var characteristic: CBCharacteristic { get }
    var offset: Int { get }
    var value: NSData? { get set }
}

extension CBATTRequest : CBATTRequestInjectable {}

// MARK: - CBCentralInjectable -
public protocol CBCentralInjectable {
    var identifier: NSUUID { get }
    var maximumUpdateValueLength: Int { get }
}

extension CBCentral : CBCentralInjectable {}

// MARK: - PeripheralManager -
public class PeripheralManager : NSObject, CBPeripheralManagerDelegate {

    // MARK: Serialize Property IO
    static let ioQueue = Queue("us.gnos.blueCap.peripheral-manager.io")

    private let WAIT_FOR_ADVERTISING_TO_STOP_POLLING_INTERVAL: Double                   = 0.25

    // MARK: Properties
    private var _name: String?
    private var cbPeripheralManager: CBPeripheralManagerInjectable!
    
    private var _afterAdvertisingStartedPromise                                 = Promise<Void>()
    private var _afterAdvertsingStoppedPromise                                  = Promise<Void>()
    private var _afterPowerOnPromise                                            = Promise<Void>()
    private var _afterPowerOffPromise                                           = Promise<Void>()
    private var _afterSeriviceAddPromise                                        = Promise<Void>()

    internal var configuredServices         = BCSerialIODictionary<CBUUID, MutableService>(PeripheralManager.ioQueue)
    internal var configuredCharcteristics   = BCSerialIODictionary<CBUUID, MutableCharacteristic>(PeripheralManager.ioQueue)

    public let peripheralQueue: Queue

    private var afterAdvertisingStartedPromise: Promise<Void> {
        get {
            return PeripheralManager.ioQueue.sync { return self._afterAdvertisingStartedPromise }
        }
        set {
            PeripheralManager.ioQueue.sync { self._afterAdvertisingStartedPromise = newValue }
        }
    }

    private var afterAdvertsingStoppedPromise: Promise<Void> {
        get {
            return PeripheralManager.ioQueue.sync { return self._afterAdvertsingStoppedPromise }
        }
        set {
            PeripheralManager.ioQueue.sync { self._afterAdvertsingStoppedPromise = newValue }
        }
    }

    private var afterPowerOnPromise: Promise<Void> {
        get {
            return PeripheralManager.ioQueue.sync { return self._afterPowerOnPromise }
        }
        set {
            PeripheralManager.ioQueue.sync { self._afterPowerOnPromise = newValue }
        }
    }

    private var afterPowerOffPromise: Promise<Void> {
        get {
            return PeripheralManager.ioQueue.sync { return self._afterPowerOffPromise }
        }
        set {
            PeripheralManager.ioQueue.sync { self._afterPowerOffPromise = newValue }
        }
    }

    private var afterSeriviceAddPromise: Promise<Void> {
        get {
            return PeripheralManager.ioQueue.sync { return self._afterSeriviceAddPromise }
        }
        set {
            PeripheralManager.ioQueue.sync { self._afterSeriviceAddPromise = newValue }
        }
    }

    public var isAdvertising: Bool {
        return self.cbPeripheralManager.isAdvertising
    }
    
    public var poweredOn: Bool {
        return self.cbPeripheralManager.state == CBPeripheralManagerState.PoweredOn
    }
    
    public var poweredOff: Bool {
        return self.cbPeripheralManager.state == CBPeripheralManagerState.PoweredOff
    }

    public var state: CBPeripheralManagerState {
        return self.cbPeripheralManager.state
    }
    
    public var services: [MutableService] {
        return Array(self.configuredServices.values)
    }

    public func service(uuid: CBUUID) -> MutableService? {
        return self.configuredServices[uuid]
    }

    public var characteristics: [MutableCharacteristic] {
        return Array(self.configuredCharcteristics.values)
    }

    // MARK: Initialize
    private override init() {
        self.peripheralQueue = Queue(dispatch_queue_create("com.gnos.us.peripheral.main", DISPATCH_QUEUE_SERIAL))
        super.init()
        self.cbPeripheralManager = CBPeripheralManager(delegate:self, queue:self.peripheralQueue.queue)
    }

    public init(queue: dispatch_queue_t, options: [String:AnyObject]?=nil) {
        self.peripheralQueue = Queue(queue)
        super.init()
        self.cbPeripheralManager = CBPeripheralManager(delegate:self, queue:self.peripheralQueue.queue, options:options)
    }

    public init(peripheralManager: CBPeripheralManagerInjectable) {
        self.peripheralQueue = Queue(dispatch_queue_create("com.gnos.us.peripheral.main", DISPATCH_QUEUE_SERIAL))
        super.init()
        self.cbPeripheralManager = peripheralManager
    }

    // MARK: Power ON/OFF
    public func powerOn() -> Future<Void> {
        Logger.debug()
        self.afterPowerOnPromise = Promise<Void>()
        if self.poweredOn {
            self.afterPowerOnPromise.success()
        }
        return self.afterPowerOnPromise.future
    }
    
    public func powerOff() -> Future<Void> {
        Logger.debug()
        self.afterPowerOffPromise = Promise<Void>()
        if self.poweredOff {
            self.afterPowerOffPromise.success()
        }
        return self.afterPowerOffPromise.future
    }

    // MARK: Advertising
    public func startAdvertising(name: String, uuids: [CBUUID]? = nil) -> Future<Void> {
        self._name = name
        self.afterAdvertisingStartedPromise = Promise<Void>()
        if !self.isAdvertising {
            var advertisementData : [String:AnyObject] = [CBAdvertisementDataLocalNameKey:name]
            if let uuids = uuids {
                advertisementData[CBAdvertisementDataServiceUUIDsKey] = uuids
            }
            self.cbPeripheralManager.startAdvertising(advertisementData)
        } else {
            self.afterAdvertisingStartedPromise.failure(BCError.peripheralManagerIsAdvertising)
        }
        return self.afterAdvertisingStartedPromise.future
    }
    
    public func startAdvertising(region: FLBeaconRegion) -> Future<Void> {
        self._name = region.identifier
        self.afterAdvertisingStartedPromise = Promise<Void>()
        if !self.isAdvertising {
            self.cbPeripheralManager.startAdvertising(region.peripheralDataWithMeasuredPower(nil))
        } else {
            self.afterAdvertisingStartedPromise.failure(BCError.peripheralManagerIsAdvertising)
        }
        return self.afterAdvertisingStartedPromise.future
    }
    
    public func stopAdvertising() -> Future<Void> {
        self._name = nil
        self.afterAdvertsingStoppedPromise = Promise<Void>()
        if self.isAdvertising {
             self.cbPeripheralManager.stopAdvertising()
            self.peripheralQueue.async{self.lookForAdvertisingToStop()}
        } else {
            self.afterAdvertsingStoppedPromise.failure(BCError.peripheralManagerIsNotAdvertising)
        }
        return self.afterAdvertsingStoppedPromise.future
    }

    // MARK: Manage Services
    public func addService(service: MutableService) -> Future<Void> {
        self.addConfiguredCharacteristics(service.characteristics)
        self.afterSeriviceAddPromise = Promise<Void>()
        if !self.isAdvertising {
            self.configuredServices[service.uuid] = service
            self.cbPeripheralManager.addService(service.cbMutableService)
            Logger.debug("service name=\(service.name), uuid=\(service.uuid)")
        } else {
            self.afterSeriviceAddPromise.failure(BCError.peripheralManagerIsAdvertising)
        }
        return self.afterSeriviceAddPromise.future
    }
    
    public func addServices(services: [MutableService]) -> Future<Void> {
        Logger.debug("service count \(services.count)")
        for service in services {
            self.addConfiguredCharacteristics(service.characteristics)
        }
        let promise = Promise<Void>()
        self.addServices(promise, services:services)
        return promise.future
    }

    public func removeService(service: MutableService) -> Future<Void> {
        let promise = Promise<Void>()
        if !self.isAdvertising {
            Logger.debug("removing service \(service.uuid.UUIDString)")
            self.removeServiceAndCharacteristics(service)
            promise.success()
        } else {
            promise.failure(BCError.peripheralManagerIsAdvertising)
        }
        return promise.future
    }
    
    public func removeAllServices() -> Future<Void> {
        let promise = Promise<Void>()
        if !self.isAdvertising {
            Logger.debug()
            self.removeAllServiceAndCharacteristics()
            promise.success()
        } else {
            promise.failure(BCError.peripheralManagerIsAdvertising)
        }
        return promise.future
    }

    // MARK: Characteristic IO
    public func updateValue(value: NSData, forCharacteristic characteristic: MutableCharacteristic) -> Bool  {
        return self.cbPeripheralManager.updateValue(value, forCharacteristic:characteristic.cbMutableChracteristic, onSubscribedCentrals:nil)
    }
    
    public func respondToRequest(request: CBATTRequestInjectable, withResult result: CBATTError) {
        if let request = request as? CBATTRequest {
            self.cbPeripheralManager.respondToRequest(request, withResult:result)
        }
    }

    // MARK: CBPeripheralManagerDelegate
    public func peripheralManagerDidUpdateState(_: CBPeripheralManager) {
        self.didUpdateState()
    }
    
    public func peripheralManager(_: CBPeripheralManager, willRestoreState dict: [String:AnyObject]) {
    }
    
    public func peripheralManagerDidStartAdvertising(_: CBPeripheralManager, error: NSError?) {
        self.didStartAdvertising(error)
    }
    
    public func peripheralManager(_: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        self.didAddService(service, error:error)
    }
    
    public func peripheralManager(_: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        self.didSubscribeToCharacteristic(characteristic, central: central)
    }
    
    public func peripheralManager(_: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        self.didUnsubscribeFromCharacteristic(characteristic, central: central)
    }
    
    public func peripheralManager(_: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
        self.didReceiveReadRequest(request, central: request.central)
    }
    
    public func peripheralManagerIsReadyToUpdateSubscribers(_: CBPeripheralManager) {
        self.isReadyToUpdateSubscribers()
    }

    public func peripheralManager(_: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        Logger.debug()
        for request in requests {
            self.didReceiveWriteRequest(request, central: request.central)
        }
    }
    
    public func didSubscribeToCharacteristic(characteristic: CBCharacteristic, central: CBCentralInjectable) {
        Logger.debug()
        self.configuredCharcteristics[characteristic.UUID]?.didSubscribeToCharacteristic(central)
    }
    
    public func didUnsubscribeFromCharacteristic(characteristic: CBCharacteristic, central: CBCentralInjectable) {
        Logger.debug()
        self.configuredCharcteristics[characteristic.UUID]?.didUnsubscribeFromCharacteristic(central)
    }
    
    public func isReadyToUpdateSubscribers() {
        Logger.debug()
        for characteristic in self.configuredCharcteristics.values {
            if characteristic.hasSubscriber {
                characteristic.peripheralManagerIsReadyToUpdateSubscribers()
            }
        }
    }
    
    public func didReceiveWriteRequest(request: CBATTRequestInjectable, central: CBCentralInjectable) {
        if let characteristic = self.configuredCharcteristics[request.characteristic.UUID] {
            Logger.debug("characteristic write request received for \(characteristic.uuid.UUIDString)")
            if characteristic.didRespondToWriteRequest(request, central: central) {
                characteristic.value = request.value
            } else {
                self.respondToRequest(request, withResult:CBATTError.RequestNotSupported)
            }
        } else {
            self.respondToRequest(request, withResult:CBATTError.UnlikelyError)
        }
    }
    
    public func didReceiveReadRequest(var request: CBATTRequestInjectable, central: CBCentralInjectable) {
        Logger.debug("chracteracteristic \(request.characteristic.UUID)")
        if let characteristic = self.configuredCharcteristics[request.characteristic.UUID] {
            Logger.debug("responding with data: \(characteristic.stringValue)")
            request.value = characteristic.value
            self.respondToRequest(request, withResult:CBATTError.Success)
        } else {
            Logger.debug("characteristic not found")
            self.respondToRequest(request, withResult:CBATTError.UnlikelyError)
        }
    }
    
    public func didUpdateState() {
        switch self.state {
        case .PoweredOn:
            Logger.debug("poweredOn")
            if self.afterPowerOnPromise.completed == false {
                self.afterPowerOnPromise.success()
            }
            break
        case .PoweredOff:
            Logger.debug("poweredOff")
            if self.afterPowerOffPromise.completed == false {
                self.afterPowerOffPromise.success()
            }
            break
        case .Resetting:
            break
        case .Unsupported:
            break
        case .Unauthorized:
            break
        case .Unknown:
            break
        }
    }
    
    public func didStartAdvertising(error: NSError?) {
        if let error = error {
            Logger.debug("failed '\(error.localizedDescription)'")
            self.afterAdvertisingStartedPromise.failure(error)
        } else {
            Logger.debug("success")
            self.afterAdvertisingStartedPromise.success()
        }
    }
    
    public func didAddService(service: CBService, error: NSError?) {
        if let error = error {
            Logger.debug("failed '\(error.localizedDescription)'")
            self.configuredServices.removeValueForKey(service.UUID)
            self.afterSeriviceAddPromise.failure(error)
        } else {
            Logger.debug("success")
            self.afterSeriviceAddPromise.success()
        }
    }

    public func addServices(promise: Promise<Void>, services: [MutableService]) {
        if services.count > 0 {
            let future = self.addService(services[0])
            future.onSuccess {
                if services.count > 1 {
                    let servicesTail = Array(services[1...services.count-1])
                    Logger.debug("services remaining \(servicesTail.count)")
                    self.addServices(promise, services:servicesTail)
                } else {
                    Logger.debug("completed")
                    promise.success()
                }
            }
            future.onFailure {(error) in
                let future = self.removeAllServices()
                future.onSuccess {
                    Logger.debug("failed '\(error.localizedDescription)'")
                    promise.failure(error)
                }
            }
        }
    }

    private func lookForAdvertisingToStop() {
        if self.isAdvertising {
            self.peripheralQueue.delay(WAIT_FOR_ADVERTISING_TO_STOP_POLLING_INTERVAL) {
                self.lookForAdvertisingToStop()
            }
        } else {
            Logger.debug("advertising stopped")
            self.afterAdvertsingStoppedPromise.success()
        }
    }

    private func addConfiguredCharacteristics(characteristics: [MutableCharacteristic]) {
        for characteristic in characteristics {
            self.configuredCharcteristics[characteristic.cbMutableChracteristic.UUID] = characteristic
        }
    }

    private func removeServiceAndCharacteristics(service: MutableService) {
        let removedCharacteristics = Array(self.configuredCharcteristics.keys).filter{(uuid) in
            for bcCharacteristic in service.characteristics {
                if uuid == bcCharacteristic.uuid {
                    return true
                }
            }
            return false
        }
        for cbCharacteristic in removedCharacteristics {
            self.configuredCharcteristics.removeValueForKey(cbCharacteristic)
        }
        self.configuredServices.removeValueForKey(service.uuid)
        self.cbPeripheralManager.removeService(service.cbMutableService)
    }
    
    private func removeAllServiceAndCharacteristics() {
        self.configuredServices.removeAll()
        self.configuredCharcteristics.removeAll()
        self.cbPeripheralManager.removeAllServices()
    }

}

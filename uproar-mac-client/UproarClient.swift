//
//  UproarClient.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 12.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import SwiftMQTT
import Result

class UproarClient: MQTTSessionDelegate {
    
    private static let deviceInChannelName = "device_in_\(Constants.token)"
    
    private(set) lazy var sendBoringAction: Action<(), (), AnyError> = self.createSendBoringAction()
    
    private lazy var mqttSession: MQTTSession = self.createMqttSession()
    
    private let isRegistered: Atomic<Bool> = Atomic(false)
    
    private let isManualDisconnected: Atomic<Bool> = Atomic(false)
    private let (disconnectSignal, disconnectObserver) = Signal<(), NoError>.pipe()
    
    init() {
        let subscribeToDeviceChannelSignal = self.subscribeToDeviceChannel()
        let sendRegisterSignal = self.sendRegister()
        let disconnectSignalProducer = SignalProducer(disconnectSignal)
        connectMqtt()
            .flatMap(.concat) { subscribeToDeviceChannelSignal }
            .flatMap(.concat) { sendRegisterSignal }
            .then(disconnectSignalProducer.take(first: 1))
            .flatMapError { _ in
                return SignalProducer<(), NoError>.empty
            }
            .delay(3.0, on: QueueScheduler.main)
            .repeat(1000)
            .start()
    }
    
    private func connectMqtt() -> SignalProducer<(), AnyError> {
        return SignalProducer {[weak self] (observer, disposable) in
            guard let strongSelf = self else {
                observer.sendCompleted()
                return
            }
            strongSelf.mqttSession.connect { (succeeded, error) -> Void in
                if succeeded {
                    print("Connected!")
                    observer.send(value: ())
                    observer.sendCompleted()
                } else {
                    print("Couldn't establish connect to cloudmqtt.com\n\(error)")
                    observer.send(error: AnyError(error))
                }
            }
        }
    }
    
    private func subscribeToDeviceChannel() -> SignalProducer<(), AnyError> {
        return SignalProducer {[weak self] (observer, disposable) in
            guard let strongSelf = self else {
                observer.sendCompleted()
                return
            }
            strongSelf.mqttSession.subscribe(to: UproarClient.deviceInChannelName, delivering: .atLeastOnce) { (succeeded, error) in
                if succeeded {
                    print("Subscribed!")
                    observer.send(value: ())
                    observer.sendCompleted()
                } else {
                    print("Couldn't subscribe to channel \(UproarClient.deviceInChannelName)\n\(error)")
                    observer.send(error: AnyError(error))
                }
            }
        }
    }
    
    private func sendRegister() -> SignalProducer<(), AnyError> {
        return SignalProducer {[weak self] (observer, disposable) in
            guard let strongSelf = self else {
                observer.sendCompleted()
                return
            }
            if strongSelf.isRegistered.value {
                print("Has registered earlier")
                observer.send(value: ())
                observer.sendCompleted()
            } else {
                strongSelf.mqttSession.publish(Constants.token.data(using: .utf8)!, in: "registry", delivering: .atLeastOnce, retain: false) { (succeeded, error) in
                    if succeeded {
                        print("Registered!")
                        if let strongSelf = self {
                            strongSelf.isRegistered.value = true
                        }
                        observer.send(value: ())
                        observer.sendCompleted()
                    } else {
                        print("Couldn't register token")
                        observer.send(error: AnyError(error))
                    }
                }
            }
        }
    }
    
    deinit {
        disconnect()
    }
    
    private func createMqttSession() -> MQTTSession {
        let tokenComponents = Constants.token.components(separatedBy: "-")
        let session = MQTTSession(host: "m21.cloudmqtt.com", port: 18552, clientID: "uproar-mac", cleanSession: true, keepAlive: 20, useSSL: false)
        session.username = "\(tokenComponents[0])-\(tokenComponents[1])"
        session.password = Constants.token
        session.delegate = self
        return session
    }
    
    private func createSendBoringAction() -> Action<(), (), AnyError> {
        return Action {[weak self] () -> SignalProducer<(), AnyError> in
            return SignalProducer { (observer, disposable) in
                guard let strongSelf = self else {
                    observer.sendCompleted()
                    return
                }
                let boringMessage = ["token": Constants.token, "update": "boring"]
                let messageData = try! JSONSerialization.data(withJSONObject: boringMessage, options: [])
                strongSelf.mqttSession.publish(messageData, in: "device_out", delivering: .atLeastOnce, retain: false, completion: { (succeeded, error) in
                    if succeeded {
                        print("Boring sent")
                        observer.send(value: ())
                        observer.sendCompleted()
                    } else {
                        print("Couldn't send 'boring'")
                        observer.send(error: AnyError(error))
                    }
                })
            }
        }
    }
    
    private func disconnect() {
        isManualDisconnected.value = true
        mqttSession.disconnect()
        mqttSession.delegate = nil
    }
    
    // MARK MQTTSessionDelegate
    
    func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession) {
        let message = String(data: data, encoding: .utf8)!
        print("\(topic):\n\(message)")
    }
    
    func mqttSocketErrorOccurred(session: MQTTSession) {
        print("Socket error occured in \(session)")
    }
    
    func mqttDidDisconnect(session: MQTTSession) {
        print("\(session) disconnected")
        if !isManualDisconnected.value {
            disconnectObserver.send(value: ())
        }
    }
}

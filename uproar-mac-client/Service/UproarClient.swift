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
    
    private lazy var mqttSession: MQTTSession = self.createMqttSession()
    
    private let isRegistered: Atomic<Bool> = Atomic(false)
    
    private let isManualDisconnected: Atomic<Bool> = Atomic(false)
    private let (disconnectSignal, disconnectObserver) = Signal<(), NoError>.pipe()
    
    let (updateSignal, updateObserver) = Signal<UproarUpdate, NoError>.pipe()
    
    init() {
        let subscribeToDeviceChannelSignal = self.subscribeToDeviceChannel()
        let sendRegisterSignal = self.sendRegister()
        let disconnectSignalProducer = SignalProducer(disconnectSignal)
        connectMqtt()
            .flatMap(.concat) { subscribeToDeviceChannelSignal }
            .flatMap(.concat) { sendRegisterSignal }
            .then(disconnectSignalProducer.take(first: 1))
            .ignoreErrors()
            .delay(10.0, on: QueueScheduler.main)
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
        if isRegistered.value {
            print("Has registered earlier")
            return SignalProducer(value: ())
        } else {
            return send(message: Constants.token.data(using: .utf8)!, toChannel: "registry")
                .on(failed: { _ in
                    print("Couldn't register token")
                }, value: {[weak self] _ in
                    print("Registered!")
                    if let strongSelf = self {
                        strongSelf.isRegistered.value = true
                    }
                })
        }
    }
    
    func send(message: UproarMessage) -> SignalProducer<(), AnyError> {
        let messageData = message.toJSONString()!.data(using: .utf8)!
        return send(message: messageData, toChannel: "device_out")
            .on(failed: { error in
                print("Couldn't send \(message.debugDescription)\n\(error.localizedDescription)")
            }, value: { _ in
                print("Sent message: \(message.debugDescription)")
            })
    }
    
    private func send(message: Data, toChannel channel: String) -> SignalProducer<(), AnyError> {
        return SignalProducer {[weak self] (observer, disposable) in
            guard let strongSelf = self else {
                observer.sendCompleted()
                return
            }
            strongSelf.mqttSession.publish(message, in: channel, delivering: .atLeastOnce, retain: false) { (succeeded, error) in
                if succeeded {
                    observer.send(value: ())
                    observer.sendCompleted()
                } else {
                    observer.send(error: AnyError(error))
                }
            }
        }
    }
    
    private func createMqttSession() -> MQTTSession {
        let tokenComponents = Constants.token.components(separatedBy: "-")
        let session = MQTTSession(host: "m21.cloudmqtt.com", port: 18552, clientID: "uproar-mac", cleanSession: true, keepAlive: 0, useSSL: false)
        session.username = "\(tokenComponents[0])-\(tokenComponents[1])"
        session.password = Constants.token
        session.delegate = self
        return session
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
        
        do {
            let update = try UproarUpdate(JSONString: message)
            updateObserver.send(value: update)
        } catch let error {
            print("\(error)")
        }
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
    
    deinit {
        disconnect()
    }
}

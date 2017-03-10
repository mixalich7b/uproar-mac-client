//
//  ViewModel.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 10.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import SwiftMQTT

class ViewModel: NSObject, MQTTSessionDelegate {
    
    private lazy var mqttSession: MQTTSession = self.createMqttSession()
    
    override init() {
        super.init()
        
        connectMqtt()
    }

    private func createMqttSession() -> MQTTSession {
        let tokenComponents = Constants.token.components(separatedBy: "-")
        let session = MQTTSession(host: "m21.cloudmqtt.com", port: 18552, clientID: "uproar-mac", cleanSession: true, keepAlive: 15, useSSL: false)
        session.username = "\(tokenComponents[0])-\(tokenComponents[1])"
        session.password = Constants.token
        session.delegate = self
        return session
    }
    
    private func connectMqtt() {
        mqttSession.connect {[weak self] (succeeded, error) -> Void in
            if succeeded {
                print("Connected!")
                self?.subscribeToDeviceChannel()
            } else {
                print("Couldn't establish connect to cloudmqtt.com\n\(error)")
            }
        }
    }
    
    private func subscribeToDeviceChannel() {
        let channelName = "device_in_\(Constants.token)"
        mqttSession.subscribe(to: channelName, delivering: .atLeastOnce) {[weak self] (succeeded, error) in
            if succeeded {
                print("Subscribed!")
                self?.sendRegister()
            } else {
                print("Couldn't subscribe to channel \(channelName)\n\(error)")
            }
        }
    }
    
    private func sendRegister() {
        mqttSession.publish(Constants.token.data(using: .utf8)!, in: "registry", delivering: .atLeastOnce, retain: false) {[weak self] (succeeded, error) in
            if succeeded {
                print("Registered!")
                self?.sendBoring()
            } else {
                print("Couldn't register token")
            }
        }
    }
    
    private func sendBoring() {
        let boringMessage = ["token": Constants.token, "update": "boring"]
        let messageData = try! JSONSerialization.data(withJSONObject: boringMessage, options: [])
        mqttSession.publish(messageData, in: "device_out", delivering: .atLeastOnce, retain: false, completion: { (succeeded, error) in
            if succeeded {
                print("Boring sent")
            } else {
                print("Couldn't send 'boring'")
            }
        })
    }
    
    deinit {
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
    }
}

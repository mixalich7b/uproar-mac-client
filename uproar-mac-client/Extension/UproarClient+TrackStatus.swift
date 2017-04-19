//
//  UproarClient.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 14.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import Result

extension UproarClient {
    func update(status: UproarTrackStatus) -> SignalProducer<(), AnyError> {
        return self.send(message: .trackStatus(status, Constants.token))
    }
}

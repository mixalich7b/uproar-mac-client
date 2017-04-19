//
//  SignalProducer.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 19.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import Result

extension SignalProducer {
    func ignoreErrors() -> SignalProducer<Value, NoError> {
        return self.flatMapError { _ in SignalProducer<Value, NoError>.empty }
    }
}

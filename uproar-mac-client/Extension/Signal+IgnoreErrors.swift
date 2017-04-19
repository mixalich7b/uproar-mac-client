//
//  Signal.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 19.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import Result

extension Signal {
    func ignoreErrors() -> Signal<Value, NoError> {
        return self.flatMapError { _ in SignalProducer<Value, NoError>.empty }
    }
}

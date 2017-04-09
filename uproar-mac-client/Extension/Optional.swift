//
//  Optional.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 09.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Foundation

extension Optional {
    func ifPresent(_ ifPresentAction: (Wrapped) -> Void, orElse orElseAction: (() -> Void)? = nil) -> Optional {
        if let unwrapped = self {
            ifPresentAction(unwrapped)
        } else {
            orElseAction?()
        }
        
        return self
    }
}

//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

struct InitializeAuthenticationConfiguration: Command {

    let identifier = "InitializeAuthenticationConfiguration"

    let configuration: AuthConfiguration

    func execute(withDispatcher dispatcher: EventDispatcher,
                        environment: Environment)
    {
        let timer = LoggingTimer(identifier).start("### Starting execution")
        let event = AuthenticationEvent(eventType: .configure(configuration))
        timer.stop("### sending \(event.type)")
        dispatcher.send(event)
    }
}

extension InitializeAuthenticationConfiguration: DefaultLogger { }

extension InitializeAuthenticationConfiguration: CustomDebugDictionaryConvertible {
    var debugDictionary: [String: Any] {
        [
            "identifier": identifier,
            "configuration": configuration
        ]
    }
}

extension InitializeAuthenticationConfiguration: CustomDebugStringConvertible {
    var debugDescription: String {
        debugDictionary.debugDescription
    }
}
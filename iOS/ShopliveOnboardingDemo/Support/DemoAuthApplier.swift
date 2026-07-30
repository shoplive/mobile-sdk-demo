//
//  DemoAuthApplier.swift
//  ShopliveOnboardingDemo — demo harness (not a copy target)
//
//  Applies the authentication mode chosen in the options tab / action sheet via UserSetup.
//  It reads DemoConfigStore and DemoCredentials, so it belongs to the harness rather than
//  ShopliveIntegration/.
//

import Foundation
import ShopliveCore

enum DemoAuthApplier {

    static func applyCurrentSelection() {
        switch DemoConfigStore.shared.authMode {
        case .guest:
            UserSetup.applyGuest()

        case .profile:
            UserSetup.applyProfile(rawUserId: "demo-user-0001",
                                   name: "Live Fan",
                                   age: 27,
                                   gender: .female,
                                   rank: 3)

        case .token:
            // The demo has no server, so it cannot mint a real JWT. If a stream token has been
            // entered we use it just to exercise the code path; otherwise we tell the user.
            // (We never fabricate a fake JWT.)
            let token = DemoCredentials.shared.streamToken
            if token.isEmpty {
                EventLog.shared.log(.error,
                    "Token mode needs a server-issued JWT — enter a token in S1 or issue one from the Queenie console")
            } else {
                UserSetup.applyToken(token)
            }
        }
    }
}

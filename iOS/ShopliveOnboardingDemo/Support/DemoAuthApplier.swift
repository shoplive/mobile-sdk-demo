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
            // The demo has no server, so it cannot mint a real JWT. It uses the User JWT entered
            // in S1 (typed or scanned from a QR); without one it tells the user.
            // (We never fabricate a fake JWT.) Same rule as the Android and Flutter demos.
            let token = DemoCredentials.shared.userJwt
            if token.isEmpty {
                EventLog.shared.log(.error,
                    "Token mode needs a server-issued JWT — enter a User JWT in S1 or issue one from the Queenie console")
            } else {
                UserSetup.applyToken(token)
            }
        }
    }
}

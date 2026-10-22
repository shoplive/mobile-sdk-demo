//
//  UserSetup.swift
//  ★ COPY THIS — mission 3 · connecting member information
//
//  Three ways to identify a viewer. These take effect from the next playback onward, so call them
//  before play.
//

import Foundation
import CryptoKit
import ShopliveCore

enum UserSetup {

    // MARK: - ① Secure authentication (recommended)

    /// Passes through a JWT your server signed and returned. The safest option.
    static func applyToken(_ jwt: String) {
        Shoplive.setUser(.token(jwt: jwt))
        shopliveLog(.call, "setUser(.token(jwt: \"\(shopliveMasked(jwt))\"))")
    }

    // MARK: - ② Simple authentication

    /// The client supplies profile values directly. For getting started without server integration.
    ///
    /// - Parameters:
    ///   - rawUserId: The **raw** member ID. It is hashed internally before being sent (see step 3).
    ///   - gender: Not optional. `.undefined` is the only way to express "not collected", and in that
    ///             case the gender key is omitted from the payload entirely.
    ///             `.neutral` means something different — "explicitly a third gender" — and is sent to
    ///             the server.
    ///   - rank: Member tier score (formerly `userScore`). Flows into personalization queries.
    static func applyProfile(rawUserId: String,
                             name: String? = nil,
                             age: Int? = nil,
                             gender: ShopliveGender = .undefined,
                             rank: Int? = nil) {

        let hashedId = hashUserId(rawUserId)

        Shoplive.setUser(.profile(
            id: hashedId,
            name: name,
            age: age,
            gender: gender,
            rank: rank
        ))

        shopliveLog(.call, "setUser(.profile(id: \"\(shopliveMasked(hashedId))\", name: \(name.map { "\"\($0)\"" } ?? "nil"), gender: .\(gender)))")
    }

    // MARK: - ③ Not logged in

    /// Viewing without a login.
    ///
    /// - Important: `.guest` is a **no-op**. On iOS the guest uid is issued by the server
    ///   (`x-sl-guest-uid`), so there is nothing for the client to set, and it does not touch the
    ///   existing authentication slots either.
    ///   To actually **clear** a logged-in state, use `logout()` — see below.
    static func applyGuest() {
        Shoplive.setUser(.guest)
        shopliveLog(.call, "setUser(.guest) — no-op (the server issues the guest uid). Use logout() to clear the session")
    }

    // MARK: - Logout

    /// Clears all three slots at once: authToken, user, and streamToken.
    ///
    /// - Important: This replaces v2's `setUser(nil)` / `clearAuth`. v3's `setUser` is non-optional,
    ///   so you cannot log out by passing nil.
    static func logout() {
        Shoplive.logout()
        shopliveLog(.call, "logout() — clears authToken, user, and streamToken together")
    }

    // MARK: - Step 3 · hashing the ID

    /// One-way transform with salt + SHA-256 so the raw member ID never lands in overlay or server
    /// logs.
    ///
    /// - Warning: Hardcoding `salt` into the app binary means it can be extracted. In a real app,
    ///   remote configuration or a server-issued token (approach ①) is the safer choice.
    static func hashUserId(_ raw: String, salt: String = "SHOPLIVE_DEMO_SALT") -> String {
        let digest = SHA256.hash(data: Data((raw + salt).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

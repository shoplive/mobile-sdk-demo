package cloud.shoplive.onboarding.demo

import cloud.shoplive.onboarding.data.DemoLog
import cloud.shoplive.onboarding.integration.ShopliveLogKind
import cloud.shoplive.onboarding.integration.shopliveLog

/**
 * Connects the copy-paste layer's log hook to this demo app's event log.
 *
 * This is the whole reason `:integration` can be copied out: every file in there
 * logs through `shopliveLog`, which does nothing until someone installs a sink.
 * The demo installs one; a customer app installs its own logger, or none at all.
 *
 * Called once from `DemoApplication.onCreate()`, before any SDK call.
 */
object DemoLogBridge {

    fun install() {
        shopliveLog = { kind, message ->
            when (kind) {
                ShopliveLogKind.CALL -> DemoLog.sdkCall(message)
                ShopliveLogKind.EVENT -> DemoLog.event(message)
                ShopliveLogKind.REQUEST -> DemoLog.request(message)
                ShopliveLogKind.RESPOND -> DemoLog.respond(message)
                ShopliveLogKind.ERROR -> DemoLog.error(message)
            }
        }
    }
}

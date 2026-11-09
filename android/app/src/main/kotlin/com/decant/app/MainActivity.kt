package com.decant.app

import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.assetpacks.AssetPackState
import com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridges Play Asset Delivery to Dart (see lib/audio/sound_packs.dart).
 *
 * The extra ambience/music loops ship as two fast-follow asset packs
 * ("ambient", "music") that Google Play downloads right after install.
 *
 *  - resolve(pack, file) -> absolute path of a sound once its pack is on disk
 *  - fetch(pack)         -> ask Play to download/prioritise the pack now
 *  - state(pack)         -> current status + byte counts
 *  - events stream       -> live download progress
 */
class MainActivity : FlutterActivity() {
    private var packs: AssetPackManager? = null
    private var sink: EventChannel.EventSink? = null

    private val listener = AssetPackStateUpdateListener { state -> sink?.success(toMap(state)) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = AssetPackManagerFactory.getInstance(applicationContext)
        packs = manager
        manager.registerListener(listener)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "decant/sound_packs").setMethodCallHandler { call, result ->
            val pack = call.argument<String>("pack")
            if (pack == null) {
                result.error("ARG", "pack is required", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "resolve" -> {
                    val file = call.argument<String>("file") ?: ""
                    val dir = manager.getPackLocation(pack)?.assetsPath()
                    val f = dir?.let { File(it, file) }
                    result.success(if (f != null && f.exists()) f.absolutePath else null)
                }
                "fetch" -> manager.fetch(listOf(pack))
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { result.success(false) }
                "state" -> manager.getPackStates(listOf(pack))
                    .addOnSuccessListener { states ->
                        val s = states.packStates()[pack]
                        result.success(if (s != null) toMap(s) else mapOf("pack" to pack, "status" to "unknown"))
                    }
                    // Not installed from Play (sideload / debug): packs can't be delivered.
                    .addOnFailureListener { e ->
                        result.success(mapOf("pack" to pack, "status" to "unavailable", "error" to e.message))
                    }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "decant/sound_packs/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
    }

    override fun onDestroy() {
        packs?.unregisterListener(listener)
        super.onDestroy()
    }

    private fun toMap(s: AssetPackState): Map<String, Any?> = mapOf(
        "pack" to s.name(),
        "status" to statusName(s.status()),
        "downloaded" to s.bytesDownloaded(),
        "total" to s.totalBytesToDownload(),
    )

    private fun statusName(status: Int): String = when (status) {
        AssetPackStatus.PENDING -> "pending"
        AssetPackStatus.DOWNLOADING -> "downloading"
        AssetPackStatus.TRANSFERRING -> "transferring"
        AssetPackStatus.COMPLETED -> "completed"
        AssetPackStatus.FAILED -> "failed"
        AssetPackStatus.CANCELED -> "canceled"
        AssetPackStatus.WAITING_FOR_WIFI -> "waitingForWifi"
        AssetPackStatus.NOT_INSTALLED -> "notInstalled"
        AssetPackStatus.REQUIRES_USER_CONFIRMATION -> "needsConfirmation"
        else -> "unknown"
    }
}

package com.mysztech.labelhub

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private companion object {
        const val bluetoothPrinterChannel = "labelhub/bluetooth_printer"
        val serialPortProfileUuid: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var bluetoothSocket: BluetoothSocket? = null
    private var bluetoothOutput: OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bluetoothPrinterChannel)
            .setMethodCallHandler(::handleBluetoothPrinterCall)
    }

    private fun handleBluetoothPrinterCall(call: MethodCall, result: MethodChannel.Result) {
        if (!hasBluetoothPermission()) {
            result.error(
                "bluetooth_permission_denied",
                "Bluetooth permission has not been granted.",
                null,
            )
            return
        }
        when (call.method) {
            "listBondedDevices" -> {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                val devices = adapter?.bondedDevices.orEmpty().map { device ->
                    mapOf("name" to device.name, "address" to device.address)
                }
                result.success(devices)
            }
            "connect" -> {
                val address = call.argument<String>("address")
                if (address.isNullOrBlank()) {
                    result.error("invalid_address", "A Bluetooth address is required.", null)
                    return
                }
                runInWorker(result) {
                    disconnectBluetoothPrinter()
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                        ?: throw IllegalStateException("Bluetooth is unavailable on this device.")
                    adapter.cancelDiscovery()
                    val socket = adapter.getRemoteDevice(address)
                        .createRfcommSocketToServiceRecord(serialPortProfileUuid)
                    socket.connect()
                    bluetoothSocket = socket
                    bluetoothOutput = socket.outputStream
                    null
                }
            }
            "write" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_data", "Printer data is required.", null)
                    return
                }
                runInWorker(result) {
                    val output = bluetoothOutput
                        ?: throw IllegalStateException("No Bluetooth printer is connected.")
                    output.write(bytes)
                    output.flush()
                    null
                }
            }
            "disconnect" -> runInWorker(result) {
                disconnectBluetoothPrinter()
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun hasBluetoothPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun runInWorker(result: MethodChannel.Result, operation: () -> Any?) {
        Thread {
            try {
                val value = operation()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("bluetooth_printer_error", error.message, null)
                }
            }
        }.start()
    }

    private fun disconnectBluetoothPrinter() {
        try {
            bluetoothOutput?.close()
        } finally {
            bluetoothOutput = null
            bluetoothSocket?.close()
            bluetoothSocket = null
        }
    }
}

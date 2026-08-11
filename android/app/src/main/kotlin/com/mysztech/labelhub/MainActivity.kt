package com.mysztech.labelhub

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private companion object {
        const val bluetoothPrinterChannel = "labelhub/bluetooth_printer"
        const val usbPrinterChannel = "labelhub/usb_printer"
        const val usbPermissionAction = "com.mysztech.labelhub.USB_PRINTER_PERMISSION"
        val serialPortProfileUuid: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var bluetoothSocket: BluetoothSocket? = null
    private var bluetoothOutput: OutputStream? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var usbOutputEndpoint: UsbEndpoint? = null
    private var pendingUsbDevice: UsbDevice? = null
    private var pendingUsbResult: MethodChannel.Result? = null

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != usbPermissionAction) return
            val device = intent.usbDevice() ?: return
            val result = pendingUsbResult ?: return
            pendingUsbResult = null
            pendingUsbDevice = null
            if (!intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                result.error("usb_permission_denied", "USB permission was not granted for ${device.deviceName}.", null)
                return
            }
            runInWorker(result) {
                connectUsbPrinter(device)
                null
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bluetoothPrinterChannel)
            .setMethodCallHandler(::handleBluetoothPrinterCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usbPrinterChannel)
            .setMethodCallHandler(::handleUsbPrinterCall)
        val filter = IntentFilter(usbPermissionAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbPermissionReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(usbPermissionReceiver)
        } catch (_: IllegalArgumentException) {
            // Activity shutdown can race a failed registration on older devices.
        }
        disconnectUsbPrinter()
        disconnectBluetoothPrinter()
        super.onDestroy()
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
                if (!hasBluetoothScanPermission()) {
                    result.error(
                        "bluetooth_permission_denied",
                        "Nearby devices permission has not been granted.",
                        null,
                    )
                    return
                }
                val address = call.argument<String>("address")
                if (address.isNullOrBlank()) {
                    result.error("invalid_address", "A Bluetooth address is required.", null)
                    return
                }
                runInWorker(result) {
                    connectBluetoothPrinter(address)
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

    private fun handleUsbPrinterCall(call: MethodCall, result: MethodChannel.Result) {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        when (call.method) {
            "listDevices" -> {
                val devices = manager.deviceList.values.map { device ->
                    mapOf(
                        "id" to device.deviceName,
                        "name" to "${device.manufacturerName ?: "USB"} ${device.productName ?: "printer"}",
                    )
                }
                result.success(devices)
            }
            "connect" -> {
                val deviceId = call.argument<String>("deviceId")
                val device = manager.deviceList.values.firstOrNull { it.deviceName == deviceId }
                if (device == null) {
                    result.error("usb_not_found", "The selected USB printer is no longer connected.", null)
                    return
                }
                if (manager.hasPermission(device)) {
                    runInWorker(result) {
                        connectUsbPrinter(device)
                        null
                    }
                    return
                }
                if (pendingUsbResult != null) {
                    result.error("usb_permission_pending", "USB permission is already being requested.", null)
                    return
                }
                pendingUsbDevice = device
                pendingUsbResult = result
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
                val permissionIntent = PendingIntent.getBroadcast(
                    this,
                    0,
                    Intent(usbPermissionAction).setPackage(packageName),
                    flags,
                )
                manager.requestPermission(device, permissionIntent)
            }
            "write" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_data", "Printer data is required.", null)
                    return
                }
                runInWorker(result) {
                    writeUsbPrinter(bytes)
                    null
                }
            }
            "disconnect" -> runInWorker(result) {
                disconnectUsbPrinter()
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun hasBluetoothPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun hasBluetoothScanPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) ==
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

    private fun connectBluetoothPrinter(address: String) {
        disconnectBluetoothPrinter()
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: throw IllegalStateException("Bluetooth is unavailable on this device.")
        adapter.cancelDiscovery()
        val socket = adapter.getRemoteDevice(address)
            .createRfcommSocketToServiceRecord(serialPortProfileUuid)
        val timeoutHandler = Handler(Looper.getMainLooper())
        val timeout = Runnable {
            try {
                socket.close()
            } catch (_: Exception) {
                // Closing the blocked connection unblocks BluetoothSocket.connect().
            }
        }
        timeoutHandler.postDelayed(timeout, 12_000)
        try {
            socket.connect()
            bluetoothSocket = socket
            bluetoothOutput = socket.outputStream
        } finally {
            timeoutHandler.removeCallbacks(timeout)
        }
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

    private fun connectUsbPrinter(device: UsbDevice) {
        disconnectUsbPrinter()
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        val connection = manager.openDevice(device)
            ?: throw IllegalStateException("Unable to open the USB printer.")
        val printerInterface = (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { usbInterface ->
                (0 until usbInterface.endpointCount).any { index ->
                    val endpoint = usbInterface.getEndpoint(index)
                    endpoint.direction == UsbConstants.USB_DIR_OUT &&
                        endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK
                }
            }
            ?: run {
                connection.close()
                throw IllegalStateException("The USB device does not expose a bulk print endpoint.")
            }
        val endpoint = (0 until printerInterface.endpointCount)
            .map { printerInterface.getEndpoint(it) }
            .first { candidate ->
                candidate.direction == UsbConstants.USB_DIR_OUT &&
                    candidate.type == UsbConstants.USB_ENDPOINT_XFER_BULK
            }
        if (!connection.claimInterface(printerInterface, true)) {
            connection.close()
            throw IllegalStateException("The USB printer interface is unavailable.")
        }
        usbConnection = connection
        usbInterface = printerInterface
        usbOutputEndpoint = endpoint
    }

    private fun writeUsbPrinter(bytes: ByteArray) {
        val connection = usbConnection ?: throw IllegalStateException("No USB printer is connected.")
        val endpoint = usbOutputEndpoint ?: throw IllegalStateException("No USB printer is connected.")
        var offset = 0
        while (offset < bytes.size) {
            val length = minOf(4096, bytes.size - offset)
            val written = connection.bulkTransfer(endpoint, bytes, offset, length, 5000)
            if (written <= 0) {
                throw IllegalStateException("The USB printer did not accept label data.")
            }
            offset += written
        }
    }

    private fun disconnectUsbPrinter() {
        val connection = usbConnection
        val printerInterface = usbInterface
        usbConnection = null
        usbInterface = null
        usbOutputEndpoint = null
        if (connection != null && printerInterface != null) {
            connection.releaseInterface(printerInterface)
        }
        connection?.close()
    }

    @Suppress("DEPRECATION")
    private fun Intent.usbDevice(): UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
    } else {
        getParcelableExtra(UsbManager.EXTRA_DEVICE)
    }
}

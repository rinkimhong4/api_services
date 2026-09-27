package com.example.pos_qr_table_ordering

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.DataOutputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "power_control/actions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val devicePolicyManager =
            getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, AppDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceAdmin" -> {
                    result.success(devicePolicyManager.isAdminActive(adminComponent))
                }

                "isDeviceOwner" -> {
                    result.success(devicePolicyManager.isDeviceOwnerApp(packageName))
                }

                "isAccessibilityEnabled" -> {
                    result.success(AppAccessibilityService.isRunning())
                }

                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }

                "requestDeviceAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                    intent.putExtra(
                        DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                        "Needed to lock the screen on demand."
                    )
                    startActivity(intent)
                    result.success(null)
                }

                "lockScreen" -> {
                    // Try Device Admin first
                    if (devicePolicyManager.isAdminActive(adminComponent)) {
                        devicePolicyManager.lockNow()
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // Try Accessibility Service lock
                    if (AppAccessibilityService.lockScreen()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    result.error(
                        "NOT_ADMIN",
                        "Device Admin or Accessibility Service is not enabled. Enable it first.",
                        null
                    )
                }

                "restart" -> {
                    // 1. Try DevicePolicyManager (Works if app is set as Device Owner / Kiosk mode)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && devicePolicyManager.isDeviceOwnerApp(packageName)) {
                        try {
                            devicePolicyManager.reboot(adminComponent)
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (e: Exception) {
                            // Continue to next fallback
                        }
                    }

                    // 2. Try PowerManager (Works if installed as a system app with android.permission.REBOOT)
                    try {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        powerManager.reboot(null)
                        result.success(true)
                        return@setMethodCallHandler
                    } catch (e: Exception) {
                        // Continue to next fallback
                    }

                    // 3. Try Root ('su' command for rooted POS devices)
                    if (runRootCommand("reboot")) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // 4. Try Accessibility Service (Shows native Restart / Power Off menu on screen)
                    if (AppAccessibilityService.showPowerDialog()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    val appName = getString(R.string.app_name)
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.error(
                        "PERMISSION_REQUIRED",
                        "Please enable '$appName' in Accessibility settings.",
                        null
                    )
                }

                "shutdown" -> {
                    // 1. Try Root ('su' command for rooted POS devices)
                    if (runRootCommand("reboot -p")) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // 2. Try Accessibility Service (Shows native Power Off dialog)
                    if (AppAccessibilityService.showPowerDialog()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    // If neither root nor accessibility is available, open accessibility settings
                    val appName = getString(R.string.app_name)
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.error(
                        "PERMISSION_REQUIRED",
                        "Please enable '$appName' in Accessibility settings.",
                        null
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun runRootCommand(command: String): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("su")
            val os = DataOutputStream(process.outputStream)
            os.writeBytes("$command\n")
            os.writeBytes("exit\n")
            os.flush()
            val exitCode = process.waitFor()
            exitCode == 0
        } catch (e: Exception) {
            false
        }
    }
}


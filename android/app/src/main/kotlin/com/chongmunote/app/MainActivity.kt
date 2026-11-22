package com.chongmunote.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    /// "문자 읽기 허락" 창의 답을 기다리는 중인 호출.
    private var pendingSmsPermission: MethodChannel.Result? = null

    private fun hasSmsPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_REQUEST) {
            pendingSmsPermission?.success(hasSmsPermission())
            pendingSmsPermission = null
        }
    }

    /// 받은 문자함에서 [since](밀리초) 이후 문자들. 최근 것부터 최대 3000개.
    private fun readInbox(since: Long): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date >= ?",
            arrayOf(since.toString()),
            "date DESC",
        )?.use { c ->
            val a = c.getColumnIndex("address")
            val b = c.getColumnIndex("body")
            val d = c.getColumnIndex("date")
            while (c.moveToNext() && out.size < 3000) {
                out.add(mapOf("address" to c.getString(a), "body" to c.getString(b), "date" to c.getLong(d)))
            }
        }
        return out
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUpdateChannel()
    }

    /// "앱 업데이트" 알림 채널. 뱃지(아이콘 점)를 켜둬요.
    private fun createUpdateChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel("updates", "앱 업데이트", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "새 버전이 나오면 알려드려요"
            setShowBadge(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 카드 승인 문자 읽기 (총무가 켰을 때만)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chongmu_note/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasSmsPermission())
                "requestPermission" -> {
                    if (hasSmsPermission()) {
                        result.success(true)
                    } else {
                        pendingSmsPermission?.success(false)
                        pendingSmsPermission = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), SMS_REQUEST)
                    }
                }
                "inbox" -> {
                    if (!hasSmsPermission()) {
                        result.error("no_permission", "문자 읽기 허락이 필요해요", null)
                    } else {
                        try {
                            result.success(readInbox((call.argument<Number>("since") ?: 0).toLong()))
                        } catch (e: Exception) {
                            result.error("read_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chongmu_note/update").setMethodCallHandler { call, result ->
            when (call.method) {
                // 설치 파일을 내려받을 폴더
                "updatesDir" -> {
                    val dir = File(cacheDir, "updates")
                    dir.mkdirs()
                    // 예전에 받아둔 설치 파일은 지워요.
                    dir.listFiles()?.forEach { it.delete() }
                    result.success(dir.absolutePath)
                }
                // 링크 열기 (후원: 토스·카카오페이)
                "openUrl" -> {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                // 안드로이드 설치 화면 열기
                "install" -> {
                    try {
                        val file = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val SMS_REQUEST = 4021
    }
}

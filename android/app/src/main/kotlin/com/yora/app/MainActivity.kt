package com.yora.app

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var channel: MethodChannel

    private var notificationPromptActive = false
    private var pendingRestore: Pair<List<String>, MethodChannel.Result>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            notificationPromptActive = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQUEST_LEGACY_WRITE)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_NOTIFICATIONS -> {
                notificationPromptActive = false
                if (pendingRestore != null) requestPermissions(arrayOf(audioReadPermission), REQUEST_AUDIO_READ)
            }
            REQUEST_AUDIO_READ -> {
                val (paths, result) = pendingRestore ?: return
                pendingRestore = null
                if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                    runRestore(paths, result)
                } else {
                    result.success(0)
                }
            }
        }
    }

    private val audioReadPermission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun legacyPublicFile(fileName: String, folder: String) =
        File(File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), folder), fileName)

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun findPublishedAudio(fileName: String, folder: String): Uri? {
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val id = contentResolver.query(
            collection,
            arrayOf(MediaStore.Audio.Media._ID),
            "${MediaStore.Audio.Media.DISPLAY_NAME}=? AND ${MediaStore.Audio.Media.RELATIVE_PATH}=?",
            arrayOf(fileName, "${Environment.DIRECTORY_MUSIC}/$folder/"),
            null
        )?.use { if (it.moveToFirst()) it.getLong(0) else null } ?: return null
        return ContentUris.withAppendedId(collection, id)
    }

    private fun isAlreadyPublished(fileName: String, folder: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return legacyPublicFile(fileName, folder).exists()
        return findPublishedAudio(fileName, folder) != null
    }

    private fun openPublishedAudio(fileName: String, folder: String): InputStream? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val file = legacyPublicFile(fileName, folder)
            return if (file.exists()) file.inputStream() else null
        }
        val uri = findPublishedAudio(fileName, folder) ?: return null
        return contentResolver.openInputStream(uri)
    }

    private fun restoreDownloadsFromMusic(paths: List<String>): Int {
        val appDir = getExternalFilesDir(null)?.canonicalPath ?: return 0
        var restored = 0
        for (path in paths) {
            val target = File(path)
            if (!target.canonicalPath.startsWith(appDir) || target.exists()) continue
            try {
                val input = openPublishedAudio(target.name, "Yora") ?: continue
                target.parentFile?.mkdirs()
                input.use { i -> target.outputStream().use { o -> i.copyTo(o) } }
                restored++
            } catch (e: Exception) {
                target.delete()
            }
        }
        return restored
    }

    private fun runRestore(paths: List<String>, result: MethodChannel.Result) {
        executor.execute {
            val restored = try { restoreDownloadsFromMusic(paths) } catch (e: Exception) { 0 }
            mainHandler.post { result.success(restored) }
        }
    }

    private fun purgePublishedFolder(folder: String) {
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), folder)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            contentResolver.delete(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                "${MediaStore.Audio.Media.DATA} LIKE ?",
                arrayOf("${dir.absolutePath}/%")
            )
            dir.deleteRecursively()
            return
        }
        contentResolver.delete(
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            "${MediaStore.Audio.Media.RELATIVE_PATH}=?",
            arrayOf("${Environment.DIRECTORY_MUSIC}/$folder/")
        )
        dir.delete()
    }

    private fun publishAudioToMediaStore(sourcePath: String, fileName: String, title: String, artist: String, album: String?, folder: String) {
        if (isAlreadyPublished(fileName, folder)) return
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.ARTIST, artist)
            if (!album.isNullOrEmpty()) put(MediaStore.Audio.Media.ALBUM, album)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
        }
        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/$folder")
            values.put(MediaStore.Audio.Media.IS_PENDING, 1)
            resolver.insert(MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values)
        } else {
            val musicDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), folder)
            if (!musicDir.exists()) musicDir.mkdirs()
            values.put(MediaStore.Audio.Media.DATA, File(musicDir, fileName).absolutePath)
            resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
        } ?: return
        try {
            val out = resolver.openOutputStream(uri) ?: throw IllegalStateException("MediaStore : flux d'écriture indisponible")
            out.use { File(sourcePath).inputStream().use { input -> input.copyTo(it) } }
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val doneValues = ContentValues()
            doneValues.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(uri, doneValues, null, null)
        } else {
            val path = values.getAsString(MediaStore.Audio.Media.DATA)
            if (path != null) MediaScannerConnection.scanFile(this, arrayOf(path), arrayOf("audio/mpeg"), null)
        }
    }

    private fun openMusicFolder(folder: String): Boolean {
        val documentId = "primary:Music/$folder"
        val uri = Uri.parse("content://com.android.externalstorage.documents/document/" + Uri.encode(documentId))
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "vnd.android.document/directory")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yora/ytdlp")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> executor.execute {
                    try {
                        YoutubeDL.getInstance().init(applicationContext)
                        FFmpeg.getInstance().init(applicationContext)
                        mainHandler.post { result.success(true) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("INIT", e.message, null) }
                    }
                }
                "update" -> executor.execute {
                    try {
                        val status = YoutubeDL.getInstance().updateYoutubeDL(applicationContext)
                        mainHandler.post { result.success(status?.name ?: "UNKNOWN") }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("UPDATE", e.message, null) }
                    }
                }
                "execute" -> {
                    val args = call.argument<List<String>>("args") ?: emptyList()
                    val id = call.argument<String>("id") ?: "0"
                    executor.execute {
                        try {
                            val request = YoutubeDLRequest(emptyList<String>())
                            request.addCommands(args)
                            val response = YoutubeDL.getInstance().execute(request, id) { _, _, line ->
                                mainHandler.post { channel.invokeMethod("line", mapOf("id" to id, "line" to line)) }
                            }
                            mainHandler.post {
                                result.success(mapOf("exitCode" to response.exitCode, "stdout" to response.out, "stderr" to response.err))
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.success(mapOf("exitCode" to 1, "stdout" to "", "stderr" to (e.message ?: "Erreur yt-dlp")))
                            }
                        }
                    }
                }
                "cancel" -> {
                    val id = call.argument<String>("id") ?: ""
                    YoutubeDL.getInstance().destroyProcessById(id)
                    result.success(true)
                }
                "openMusicFolder" -> result.success(openMusicFolder(call.argument<String>("folder") ?: "Yora"))
                "publishAudio" -> executor.execute {
                    try {
                        val sourcePath = call.argument<String>("sourcePath")!!
                        val fileName = call.argument<String>("fileName")!!
                        val title = call.argument<String>("title") ?: fileName
                        val artist = call.argument<String>("artist") ?: ""
                        val album = call.argument<String>("album")
                        val folder = call.argument<String>("folder") ?: "Yora"
                        publishAudioToMediaStore(sourcePath, fileName, title, artist, album, folder)
                        mainHandler.post { result.success(true) }
                    } catch (e: Exception) {
                        mainHandler.post { result.success(false) }
                    }
                }
                "restoreDownloads" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    if (checkSelfPermission(audioReadPermission) == PackageManager.PERMISSION_GRANTED) {
                        runRestore(paths, result)
                    } else if (pendingRestore != null) {
                        result.success(0)
                    } else {
                        pendingRestore = paths to result
                        if (!notificationPromptActive) requestPermissions(arrayOf(audioReadPermission), REQUEST_AUDIO_READ)
                    }
                }
                "purgePublishedFolder" -> executor.execute {
                    try {
                        val folder = call.argument<String>("folder")!!
                        purgePublishedFolder(folder)
                        mainHandler.post { result.success(true) }
                    } catch (e: Exception) {
                        mainHandler.post { result.success(false) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 1001
        private const val REQUEST_LEGACY_WRITE = 1002
        private const val REQUEST_AUDIO_READ = 1003
    }
}

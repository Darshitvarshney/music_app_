import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../features/search/model/song_model.dart';
import '../../features/search/repositories/search_repository.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  static DownloadService get instance => _instance;

  DownloadService._internal() {
    _init();
  }

  final SearchRepository _searchRepository = SearchRepository();

  bool _isInitialized = false;
  Directory? _baseDir;
  Directory? _songsDir;
  Directory? _artworkDir;

  final Map<String, SongModel> _downloadedSongs = {};
  final Map<String, int> _downloadedSizes = {};
  final Map<String, String> _localArtworkPaths = {};
  final Map<String, double> _downloadProgress = {};
  final Set<String> _activeDownloads = {};

  bool get isInitialized => _isInitialized;
  List<SongModel> get downloadedSongs => _downloadedSongs.values.toList();
  int get totalDownloadedCount => _downloadedSongs.length;

  int get totalStorageBytes {
    return _downloadedSizes.values.fold(0, (sum, size) => sum + size);
  }

  String get totalFormattedStorage {
    final bytes = totalStorageBytes;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool isDownloaded(String songId) {
    return _downloadedSongs.containsKey(songId);
  }

  bool isDownloading(String songId) {
    return _activeDownloads.contains(songId);
  }

  double getDownloadProgress(String songId) {
    return _downloadProgress[songId] ?? 0.0;
  }

  String? getLocalAudioPath(String songId) {
    final song = _downloadedSongs[songId];
    if (song != null && song.mediaUrl.isNotEmpty && File(song.mediaUrl).existsSync()) {
      return song.mediaUrl;
    }
    return null;
  }

  String? getLocalArtworkPath(String songId) {
    final path = _localArtworkPaths[songId];
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  int getSongFileSize(String songId) {
    return _downloadedSizes[songId] ?? 0;
  }

  String formatSongFileSize(String songId) {
    final bytes = getSongFileSize(songId);
    if (bytes <= 0) return '';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> init() async {
    await _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = Directory('${appDir.path}/music_app_downloads');
      _songsDir = Directory('${_baseDir!.path}/songs');
      _artworkDir = Directory('${_baseDir!.path}/artwork');

      if (!await _songsDir!.exists()) {
        await _songsDir!.create(recursive: true);
      }
      if (!await _artworkDir!.exists()) {
        await _artworkDir!.create(recursive: true);
      }

      await _loadManifest();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing DownloadService: $e');
    }
  }

  Future<void> _loadManifest() async {
    if (_baseDir == null) return;
    final manifestFile = File('${_baseDir!.path}/downloads_manifest.json');
    if (!await manifestFile.exists()) return;

    try {
      final raw = await manifestFile.readAsString();
      final List<dynamic> list = jsonDecode(raw);
      bool manifestChanged = false;

      _downloadedSongs.clear();
      _downloadedSizes.clear();
      _localArtworkPaths.clear();

      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          String? audioPath = item['local_audio_path']?.toString() ??
              item['media_url']?.toString();

          // Verify if audio file exists at stored path
          bool fileExists = audioPath != null && await File(audioPath).exists();

          // Fallback: check inside songs directory by safe ID
          if (!fileExists && _songsDir != null) {
            final safeId = _sanitizeFilename(id);
            final fallbackCandidates = [
              File('${_songsDir!.path}/$safeId.mp3'),
              File('${_songsDir!.path}/$safeId.m4a'),
              File('${_songsDir!.path}/$safeId.aac'),
            ];
            for (final cand in fallbackCandidates) {
              if (await cand.exists()) {
                audioPath = cand.path;
                fileExists = true;
                manifestChanged = true;
                break;
              }
            }
          }

          if (fileExists && audioPath != null) {
            final song = SongModel.fromMap(item).copyWith(
              mediaUrl: audioPath,
            );
            _downloadedSongs[id] = song;
            _downloadedSizes[id] =
                (item['file_size'] as num?)?.toInt() ??
                (await File(audioPath).length());

            final artworkPath = item['local_artwork_path']?.toString();
            if (artworkPath != null && await File(artworkPath).exists()) {
              _localArtworkPaths[id] = artworkPath;
            }
          } else {
            manifestChanged = true;
          }
        }
      }

      if (manifestChanged) {
        await _saveManifest();
      }
    } catch (e) {
      debugPrint('Error reading downloads manifest: $e');
    }
  }

  Future<void> _saveManifest() async {
    if (_baseDir == null) return;
    try {
      final manifestFile = File('${_baseDir!.path}/downloads_manifest.json');
      final list = _downloadedSongs.values.map((song) {
        final map = song.toMap();
        map['local_audio_path'] = song.mediaUrl;
        map['file_size'] = _downloadedSizes[song.id] ?? 0;
        if (_localArtworkPaths.containsKey(song.id)) {
          map['local_artwork_path'] = _localArtworkPaths[song.id];
        }
        return map;
      }).toList();

      await manifestFile.writeAsString(jsonEncode(list), flush: true);
    } catch (e) {
      debugPrint('Error saving downloads manifest: $e');
    }
  }

  String _sanitizeFilename(String input) {
    final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return sanitized.isNotEmpty ? sanitized : 'song_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _detectExtension(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m4a')) return '.m4a';
    if (lower.contains('.aac')) return '.aac';
    if (lower.contains('.ogg')) return '.ogg';
    if (lower.contains('.wav')) return '.wav';
    return '.mp3';
  }

  /// Downloads a song to the user's device for 100% offline playback.
  Future<bool> downloadSong(
    SongModel song, {
    Function(double progress)? onProgress,
  }) async {
    if (isDownloaded(song.id)) return true;
    if (isDownloading(song.id)) return false;

    await _init();
    if (_songsDir == null || _artworkDir == null) {
      throw Exception('Device storage not accessible.');
    }

    _activeDownloads.add(song.id);
    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    final safeId = _sanitizeFilename(song.id);
    final tempAudioFile = File('${_songsDir!.path}/$safeId.tmp');
    final client = http.Client();

    try {
      SongModel activeSong = song;

      // 1. Resolve mediaUrl if missing or empty
      if (activeSong.mediaUrl.trim().isEmpty || !activeSong.mediaUrl.startsWith('http')) {
        final resolved = await _searchRepository.resolvePlayableSong(
          activeSong,
          forceResolve: true,
        );
        if (resolved != null && resolved.mediaUrl.trim().startsWith('http')) {
          activeSong = resolved;
        } else {
          throw Exception('Unable to locate audio stream for "${song.song}".');
        }
      }

      // 2. Prepare HTTP streaming request
      http.StreamedResponse response;
      try {
        final request = http.Request('GET', Uri.parse(activeSong.mediaUrl.trim()));
        response = await client.send(request);
      } catch (e) {
        // Re-resolve in case URL is stale/expired
        final resolved = await _searchRepository.resolvePlayableSong(
          activeSong,
          forceResolve: true,
        );
        if (resolved != null && resolved.mediaUrl != activeSong.mediaUrl) {
          activeSong = resolved;
          final retryReq = http.Request('GET', Uri.parse(activeSong.mediaUrl.trim()));
          response = await client.send(retryReq);
        } else {
          rethrow;
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Try fresh resolve on HTTP error (e.g., 403 expired signed token)
        final resolved = await _searchRepository.resolvePlayableSong(
          activeSong,
          forceResolve: true,
        );
        if (resolved != null && resolved.mediaUrl.trim().isNotEmpty) {
          activeSong = resolved;
          final retryReq = http.Request('GET', Uri.parse(activeSong.mediaUrl.trim()));
          response = await client.send(retryReq);
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Download failed with server status ${response.statusCode}');
      }

      final ext = _detectExtension(activeSong.mediaUrl);
      final finalAudioFile = File('${_songsDir!.path}/$safeId$ext');

      if (await tempAudioFile.exists()) {
        await tempAudioFile.delete();
      }

      // 3. Stream bytes to temp file with progress tracking
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = tempAudioFile.openWrite();
      DateTime lastNotify = DateTime.now();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          _downloadProgress[song.id] = progress;
          onProgress?.call(progress);

          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds > 200) {
            lastNotify = now;
            notifyListeners();
          }
        }
      }

      await sink.flush();
      await sink.close();

      // Ensure target file doesn't collide
      if (await finalAudioFile.exists()) {
        await finalAudioFile.delete();
      }
      await tempAudioFile.rename(finalAudioFile.path);

      final downloadedSize = await finalAudioFile.length();

      // 4. Download and cache album artwork locally for offline viewing
      String? localArtworkPath;
      final rawImageUrl = activeSong.image.trim();
      if (rawImageUrl.isNotEmpty && rawImageUrl.startsWith('http')) {
        try {
          final artFile = File('${_artworkDir!.path}/$safeId.jpg');
          final imgRes = await http.get(Uri.parse(rawImageUrl)).timeout(
                const Duration(seconds: 10),
              );
          if (imgRes.statusCode == 200) {
            await artFile.writeAsBytes(imgRes.bodyBytes, flush: true);
            localArtworkPath = artFile.path;
            _localArtworkPaths[song.id] = localArtworkPath;
          }
        } catch (e) {
          debugPrint('Could not download artwork for offline view: $e');
        }
      }

      // 5. Store completed offline song model
      final offlineSong = activeSong.copyWith(
        mediaUrl: finalAudioFile.path,
        image: localArtworkPath ?? activeSong.image,
      );

      _downloadedSongs[song.id] = offlineSong;
      _downloadedSizes[song.id] = downloadedSize;
      await _saveManifest();

      _downloadProgress.remove(song.id);
      _activeDownloads.remove(song.id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error downloading song "${song.song}": $e');
      if (await tempAudioFile.exists()) {
        try {
          await tempAudioFile.delete();
        } catch (_) {}
      }
      _downloadProgress.remove(song.id);
      _activeDownloads.remove(song.id);
      notifyListeners();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Removes a downloaded song and deletes its local audio and artwork files from the device.
  Future<bool> deleteSong(String songId) async {
    try {
      final song = _downloadedSongs[songId];
      if (song != null) {
        if (song.mediaUrl.isNotEmpty) {
          final audioFile = File(song.mediaUrl);
          if (await audioFile.exists()) {
            await audioFile.delete();
          }
        }
      }

      final artPath = _localArtworkPaths[songId];
      if (artPath != null) {
        final artFile = File(artPath);
        if (await artFile.exists()) {
          await artFile.delete();
        }
      }

      _downloadedSongs.remove(songId);
      _downloadedSizes.remove(songId);
      _localArtworkPaths.remove(songId);
      _downloadProgress.remove(songId);
      _activeDownloads.remove(songId);

      await _saveManifest();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting downloaded song $songId: $e');
      return false;
    }
  }

  /// Deletes all downloaded songs from device storage.
  Future<void> deleteAllDownloads() async {
    try {
      final ids = List<String>.from(_downloadedSongs.keys);
      for (final id in ids) {
        await deleteSong(id);
      }
    } catch (e) {
      debugPrint('Error clearing all downloads: $e');
    }
  }
}

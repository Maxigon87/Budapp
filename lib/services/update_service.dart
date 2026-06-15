import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();

  factory UpdateService() {
    return _instance;
  }

  UpdateService._internal();

  /// Checks Firestore for updates and displays the update dialog if available.
  Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    try {
      // 1. Get current installed app version
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion =
          "${packageInfo.version}+${packageInfo.buildNumber}";

      // 2. Fetch the target configuration document from Firestore
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) {
        debugPrint(
            "UpdateService: app_config/version document does not exist in Firestore.");
        return;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final String latestVersion = data['latestVersion'] ?? '';
      final String downloadUrl = data['downloadUrl'] ?? '';
      final List<dynamic> changelog = data['changelog'] ?? [];

      if (latestVersion.isEmpty || downloadUrl.isEmpty) {
        debugPrint(
            "UpdateService: Missing required fields in Firestore config.");
        return;
      }

      // 3. Compare versions
      final bool updateAvailable =
          _isNewerVersion(currentVersion, latestVersion);

      if (updateAvailable) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            currentVersion: packageInfo.version,
            latestVersion: latestVersion.split('+')[0],
            changelog: changelog.map((e) => e.toString()).toList(),
            downloadUrl: downloadUrl,
          );
        }
      } else {
        debugPrint("UpdateService: App is up to date ($currentVersion).");
      }
    } catch (e) {
      debugPrint("UpdateService Error: $e");
    }
  }

  /// Helper method to compare version strings (semver + build number)
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('+');
      final latestParts = latest.split('+');

      final currentSemVer =
          currentParts[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestSemVer =
          latestParts[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = currentSemVer.length > latestSemVer.length
          ? currentSemVer.length
          : latestSemVer.length;
      for (int i = 0; i < maxLength; i++) {
        final currentVal = i < currentSemVer.length ? currentSemVer[i] : 0;
        final latestVal = i < latestSemVer.length ? latestSemVer[i] : 0;
        if (latestVal > currentVal) return true;
        if (latestVal < currentVal) return false;
      }

      // If semantic versions are identical, check build numbers if available
      final currentBuild =
          currentParts.length > 1 ? (int.tryParse(currentParts[1]) ?? 0) : 0;
      final latestBuild =
          latestParts.length > 1 ? (int.tryParse(latestParts[1]) ?? 0) : 0;
      return latestBuild > currentBuild;
    } catch (e) {
      debugPrint("Error comparing versions: $e");
      return false;
    }
  }

  /// Displays the modern update prompt dialog
  void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required List<String> changelog,
    required String downloadUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with update icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "¡Nueva Versión!",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // App description text
              Text(
                "Hay una actualización disponible con novedades y mejoras de rendimiento. Por favor actualiza la aplicación.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Version details cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Instalada",
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentVersion,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Disponible",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latestVersion,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Changelog section
              if (changelog.isNotEmpty) ...[
                const Text(
                  "Novedades:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: changelog.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "• ",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                changelog[index],
                                style:
                                    const TextStyle(fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Más Tarde",
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close details dialog
                      _showDownloadProgressDialog(context, downloadUrl);
                    },
                    child: const Text("Actualizar"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Custom downloader wrapper that handles calling back state settings
  Future<void> _downloadAndInstallApk({
    required String url,
    required CancelToken cancelToken,
    required void Function(double progress, String progressStr) onProgress,
    required VoidCallback onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/budapp-update.apk';

      // Delete if file already exists to avoid issues
      final file = File(apkPath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();

      // Let's download the APK
      await dio.download(
        url,
        apkPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final double rawProgress = received / total;
            final int percentage = (rawProgress * 100).toInt();
            // We call onProgress which triggers inside our dialog
            // Note: Since standard Dio callbacks run outside Flutter build,
            // we will need to update the StatefulBuilder's state.
            // We will manage it by passing the setState call.
            _updateDialogState?.call(rawProgress, "$percentage%");
          }
        },
      );

      onComplete();

      // Launch the Android installer automatically
      final result = await OpenFilex.open(apkPath);
      debugPrint("OpenFilex result: ${result.message} (Type: ${result.type})");
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint("Download cancelled by user.");
      } else {
        onError(e.toString());
      }
    }
  }

  // A tiny state helper to update the download dialog from the async thread
  void Function(double p, String pStr)? _updateDialogState;

  // Let's re-define the show progress dialog to correctly bind the stateful builder's state-setting method
  void showProgressDialogWithState(BuildContext context, String url) {
    // Reset state helper
    _updateDialogState = null;
    double progress = 0.0;
    String progressStr = "0%";
    CancelToken cancelToken = CancelToken();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Bind the helper to call setState inside this dialog
            _updateDialogState = (p, pStr) {
              setStateDialog(() {
                progress = p;
                progressStr = pStr;
              });
            };

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_download_outlined,
                    size: 48,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Descargando Actualización",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Por favor no cierres la aplicación...",
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progressStr,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () {
                          cancelToken.cancel();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Call download
    _downloadAndInstallApk(
      url: url,
      cancelToken: cancelToken,
      onProgress: (p, pStr) {
        // Handled by _updateDialogState
      },
      onComplete: () {
        if (context.mounted) {
          Navigator.pop(context); // Close the progress dialog
        }
      },
      onError: (err) {
        if (context.mounted) {
          Navigator.pop(context); // Close progress dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al descargar actualización: $err'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  // A wrapper for triggering showProgressDialogWithState
  void _showDownloadProgressDialog(BuildContext context, String url) {
    showProgressDialogWithState(context, url);
  }
}

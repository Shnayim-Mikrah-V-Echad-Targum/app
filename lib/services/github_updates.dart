import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks GitHub Releases for a newer version of the Windows/desktop app.
/// Points users at https://github.com/Shnayim-Mikrah-V-Echad-Targum/app/releases
class GithubUpdates {
  static const _repo = 'Shnayim-Mikrah-V-Echad-Targum/app';
  static const _releasesUrl = 'https://github.com/$_repo/releases';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  /// Returns the latest tag (without leading 'v') if it is newer than the
  /// currently installed version, otherwise null.
  Future<String?> checkForNewerVersion() async {
    if (kIsWeb) return null; // web has its own update path
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "0.0.1"

      final res = await http.get(
        Uri.parse(_apiUrl),
        headers: const {'User-Agent': 'ShnayimMikrah'},
      );
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '');
      if (tag == null) return null;

      if (_isNewer(tag, current)) return tag;
    } catch (e) {
      debugPrint('GithubUpdates check failed: $e');
    }
    return null;
  }

  /// Opens the GitHub Releases page so the user can download the new MSIX
  /// (or run the install.ps1 one-liner).
  Future<void> openReleasesPage() async {
    final uri = Uri.parse(_releasesUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Simple dotted numeric comparison (0.0.1 < 0.0.2 < 0.1.0 < 1.0.0).
  // Not a full semver parser, but enough for X.Y.Z tags.
  bool _isNewer(String latest, String current) {
    final a = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final b = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai > bi) return true;
      if (ai < bi) return false;
    }
    return false;
  }
}

final githubUpdatesProvider = Provider<GithubUpdates>((ref) => GithubUpdates());

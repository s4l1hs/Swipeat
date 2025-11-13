import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/color_utils.dart';
import '../l10n/app_localizations.dart';
import '../locale_provider.dart';
// Theme toggling removed; single-theme app. (main.dart no longer exports ThemeNotifier)
import '../providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/mandatory_profile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  bool _isSavingLanguage = false;
  // ignore: unused_field
  bool _isLoadingProfile = false;

  String _currentLanguageCode = 'en';
  String? _username; 

  late final AnimationController _animationController;

  final Map<String, String> _supportedLanguages = {
    'en': 'English', 'tr': 'Türkçe', 'de': 'Deutsch', 'fr': 'Français', 'es': 'Español',
    'it': 'Italiano', 'ru': 'Русский', 'zh': '中文 (简体)', 'hi': 'हिन्दी', 'ja': '日本語', 'ar': 'العربية',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<String?> _getIdToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // theme is fixed for Swipeat; we don't persist theme mode

      final token = await _getIdToken();
      if (token == null) {
        // Not signed in — silently return without showing an error.
        return;
      }

      // Use the API path implemented in the backend
      final uri = Uri.parse("$backendBaseUrl/api/me");
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

  if (response.statusCode == 200 && mounted) {
        final profile = jsonDecode(response.body) as Map<String, dynamic>;
        final firebaseName = FirebaseAuth.instance.currentUser?.displayName;
        final backendName = (profile['name'] as String?) ?? '';
        final languageCode = (profile['language_code'] as String?) ?? 'en';
        setState(() {
          _currentLanguageCode = languageCode;
          _username = (firebaseName != null && firebaseName.isNotEmpty) ? firebaseName : (backendName.isNotEmpty ? backendName : null);
        });

        if (mounted) {
          Provider.of<LocaleProvider>(context, listen: false).setLocale(_currentLanguageCode);
        }
      } else if (response.statusCode == 404) {
        // No profile created yet; that's fine — user will be routed through profile flow elsewhere.
        return;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      // don't surface routine profile-load errors in UI; just log
      debugPrint('Settings: failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }
  Future<void> _saveLanguage(String langCode) async {
    if (_isSavingLanguage) return;
    setState(() => _isSavingLanguage = true);
    try {
      final token = await _getIdToken();
      if (token == null) throw Exception("User not logged in");

      final api = ApiService();
      await api.updateLanguage(token, langCode);
      if (mounted) {
        Provider.of<LocaleProvider>(context, listen: false).setLocale(langCode);
        setState(() => _currentLanguageCode = langCode);
      }
    } catch (e) {
      if (mounted) {
        final msg = AppLocalizations.of(context)?.failedToSaveLanguage ?? "Failed to save language: $e";
        _showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) setState(() => _isSavingLanguage = false);
    }
  }

  // Notifications and appearance settings removed — Swipeat does not use push notifications or theme toggles.

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
  }

  void _showSignOutConfirmation() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text(localizations.signOut),
        content: Text(localizations.signOutConfirmation),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(localizations.cancel)),
          TextButton(onPressed: () async {
            Navigator.of(ctx).pop();
            await FirebaseAuth.instance.signOut();
            try { await GoogleSignIn().signOut(); } catch (_) {}
          }, child: Text(localizations.signOut, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [], // help icon removed
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary.withOpacitySafe(0.12), theme.colorScheme.secondary.withOpacitySafe(0.06)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Positioned(top: -40.h, left: -24.w, child: _decorBlob(theme.colorScheme.primary.withOpacitySafe(0.08), 180.w)),
          Positioned(bottom: -80.h, right: -60.w, child: _decorBlob(theme.colorScheme.secondary.withOpacitySafe(0.07), 260.w)),

            ListView(
              padding: EdgeInsets.fromLTRB(18.w, 0.h, 18.w, 12.h),
              children: [
                Transform.translate(
                  offset: Offset(0, -0.h),
                  child: FadeTransition(opacity: _animationController, child: _buildProfileHeader(theme, localizations)),
                ),
                SizedBox(height: 4.h),

                _buildCardSection(title: localizations.general, child: Column(children: [
                  _buildLanguageTile(localizations, theme),
                ])),
                SizedBox(height: 18.h),
                _buildCardSection(title: localizations.account, child: Column(children: [
                  const Divider(color: Colors.white12, height: 1),
                  _buildEditProfileTile(localizations, theme),
                  const Divider(color: Colors.white12, height: 1),
                  _buildSignOutTile(localizations, theme),
                ])),
                SizedBox(height: 28.h),
                Center(child: Text('Flow7 • v1.0.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 12.sp))),
                SizedBox(height: 8.h),
              ],
            ),
        ],
      ),
    );
  }

  Widget _decorBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, AppLocalizations localizations) {
    final provider = Provider.of<UserProvider?>(context);
    final profile = provider?.profile;
    final displayName = (profile as dynamic)?.username ?? _username ?? localizations.anonymous ?? 'Anonymous';

    String memberSinceText = localizations.memberSince;
    try {
      final firebaseCreation = FirebaseAuth.instance.currentUser?.metadata.creationTime;
      if (firebaseCreation != null) {
        memberSinceText = '${localizations.memberSince} ${firebaseCreation.year}';
      } else {
        final joinedRaw = (profile as dynamic)?['created_at'] ?? (profile as dynamic)?['joined_at'] ?? (profile as dynamic)?['member_since'];
        if (joinedRaw != null) {
          final parsed = DateTime.tryParse(joinedRaw.toString());
          if (parsed != null) memberSinceText = '${localizations.memberSince} ${parsed.year}';
        }
      }
    } catch (_) {
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      color: theme.colorScheme.surface.withOpacitySafe(0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 72.w, height: 72.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [theme.colorScheme.secondary, theme.colorScheme.primary]),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12.r, offset: Offset(0,8.h))],
                  ),
                  child: Center(child: Text((displayName.isNotEmpty)? displayName[0].toUpperCase() : 'A', style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.bold))),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(displayName, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ]),
                    SizedBox(height: 4.h),
                    Text(memberSinceText, style: TextStyle(color: Colors.white70, fontSize: 12.sp), overflow: TextOverflow.ellipsis),
                  ]),
                )
              ],
            ),
            SizedBox(height: 8.h),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection({required String title, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.only(left: 6.w, bottom: 8.h), child: Text(title.toUpperCase(), style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
      Card(
        color: Theme.of(context).colorScheme.surface.withOpacitySafe(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h), child: child),
      )
    ]);
  }

  Widget _buildLanguageTile(AppLocalizations localizations, ThemeData theme) {
    return ListTile(
  leading: CircleAvatar(backgroundColor: theme.colorScheme.primary.withOpacitySafe(0.12), child: Icon(Icons.language, color: theme.colorScheme.tertiary)),
      title: Text(localizations.applicationLanguage),
      subtitle: Text(_supportedLanguages[_currentLanguageCode] ?? 'English'),
      trailing: _isSavingLanguage ? SizedBox(width: 24.w, height: 24.w, child: const CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.keyboard_arrow_right, color: Colors.white70),
      onTap: () => _showLanguageBottomSheet(localizations, theme),
    );
  }

  // Theme and Notifications tiles removed — Swipeat uses a single theme and has no push notifications.

  Widget _buildSignOutTile(AppLocalizations localizations, ThemeData theme) {
    return ListTile(
      leading: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.logout, color: theme.colorScheme.secondary)),
      title: Text(localizations.signOut, style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600)),
      onTap: () => _showSignOutConfirmation(),
    );
  }

  Widget _buildEditProfileTile(AppLocalizations localizations, ThemeData theme) {
    return ListTile(
      leading: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.person, color: theme.colorScheme.primary)),
      title: Text('Profilimi Düzenle', style: TextStyle(fontWeight: FontWeight.w600)),
      onTap: () async {
        final token = await _getIdToken();
        if (token == null) {
          _showErrorSnackBar('Oturum açılmamış.');
          return;
        }
        // Navigate to the optional mandatory profile screen so user can edit details
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MandatoryProfileScreen(idToken: token, displayName: FirebaseAuth.instance.currentUser?.displayName)));
      },
    );
  }

  void _showLanguageBottomSheet(AppLocalizations localizations, ThemeData theme) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) {
      return StatefulBuilder(builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40.w, height: 4.h, margin: EdgeInsets.symmetric(vertical: 8.h), decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2.r))),
            Text(localizations.applicationLanguage, style: theme.textTheme.titleMedium),
            SizedBox(height: 10.h),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              childAspectRatio: 3,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              children: _supportedLanguages.entries.map((entry) {
                final isSelected = entry.key == _currentLanguageCode;
                final isLight = theme.brightness == Brightness.light;
        final bgColor = isSelected
          ? theme.colorScheme.primary
          : (isLight ? theme.colorScheme.primary.withOpacitySafe(0.12) : Colors.white10);
                final txtColor = isSelected
                    ? Colors.white
                    : (isLight ? theme.colorScheme.primary : Colors.white70);

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _saveLanguage(entry.key);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
                    ),
                    child: Center(child: Text(entry.value, textAlign: TextAlign.center, style: TextStyle(color: txtColor, fontSize: 13.sp))),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 10.h),
          ]),
        );
      });
    });
  }
}

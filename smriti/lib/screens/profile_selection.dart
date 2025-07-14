import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/sub_user_profile.dart';
import '../storage/sub_user_profile_storage.dart';
import 'add_profile_page.dart';
import 'profile_home_page.dart';
import 'dart:async';

class ProfileSelectionPage extends StatefulWidget {
  const ProfileSelectionPage({Key? key}) : super(key: key);

  @override
  State<ProfileSelectionPage> createState() => _ProfileSelectionPageState();
}

class _ProfileSelectionPageState extends State<ProfileSelectionPage> {
  List<SubUserProfile> _profiles = [];
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _userInteracted = false;

  static const double cardWidth = 180;
  static const double cardHeight = 240;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_userInteracted) return;
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current < maxScroll) {
        _scrollController.jumpTo((current + 0.7).clamp(0, maxScroll));
      } else {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _onUserInteraction() {
    if (!_userInteracted) {
      setState(() {
        _userInteracted = true;
      });
      _autoScrollTimer?.cancel();
    }
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    final profiles = await SubUserProfileStorage().getProfiles();
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _addProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddProfilePage()),
    );
    if (result == true) {
      _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 80, height: 80),
                const SizedBox(height: 24),
                Text(
                  'Welcome back 👋',
                  style: AppTextStyles.headline.copyWith(fontSize: 36),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _loading
                    ? CircularProgressIndicator()
                    : SizedBox(
                        height: cardHeight,
                        child: Listener(
                          onPointerDown: (_) => _onUserInteraction(),
                          child: ListView.separated(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _profiles.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 36),
                            itemBuilder: (context, index) {
                              if (index == _profiles.length) {
                                return GestureDetector(
                                  onTap: _addProfile,
                                  child: Card(
                                    color: AppColors.card,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 6,
                                    shadowColor: AppColors.border.withOpacity(0.10),
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 54,
                                            backgroundColor: AppColors.primary.withOpacity(0.08),
                                            child: Icon(Icons.add, size: 54, color: AppColors.primary),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'Add',
                                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final profile = _profiles[index];
                              return GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfileHomePage(profile: profile),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadProfiles();
                                  }
                                },
                                child: Card(
                                  color: AppColors.card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 6,
                                  shadowColor: AppColors.border.withOpacity(0.10),
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 54,
                                          backgroundColor: AppColors.primary.withOpacity(0.08),
                                          child: Text(
                                            profile.initials.isNotEmpty ? profile.initials : '',
                                            style: AppTextStyles.avatarInitials.copyWith(fontSize: 48),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          profile.name,
                                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (profile.relation.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              profile.relation,
                                              style: AppTextStyles.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
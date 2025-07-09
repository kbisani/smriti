import 'package:flutter/material.dart';
import '../models/sub_user_profile.dart';
import '../theme.dart';
import 'record_page.dart';

class ProfileHomePage extends StatefulWidget {
  final SubUserProfile profile;
  const ProfileHomePage({required this.profile, Key? key}) : super(key: key);

  @override
  State<ProfileHomePage> createState() => _ProfileHomePageState();
}

class _ProfileHomePageState extends State<ProfileHomePage> {
  static const Color darkIndigo = Color(0xFF283593);
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _goToRecordTab() {
    _onNavTap(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: Text(
                  widget.profile.name.toUpperCase(),
                  style: AppTextStyles.headline.copyWith(fontSize: 24),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.textPrimary),
              onPressed: () {/* TODO: Edit profile */},
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            // Home Tab
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        color: Colors.white,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('Prompt of the Day', style: AppTextStyles.label.copyWith(fontSize: 16)),
                              const SizedBox(height: 16),
                              Text(
                                'What was a lesson your mom taught you that you’ll always remember?',
                                style: AppTextStyles.headline.copyWith(fontSize: 20, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: Icon(Icons.mic),
                                label: Text('Record your response'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkIndigo,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                onPressed: _goToRecordTab,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: Icon(Icons.photo, color: AppColors.textPrimary),
                      label: Text('Catalogue Old Photos', style: AppTextStyles.body),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border)),
                        textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {/* TODO: Catalogue photos */},
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: Icon(Icons.chat_bubble_outline),
                      label: Text('Free Conversation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkIndigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {/* TODO: Free conversation */},
                    ),
                  ],
                ),
              ),
            ),
            // Record Tab
            RecordPage(prompt: 'What was a lesson your mom taught you that you’ll always remember?'),
            // Timeline Tab (placeholder)
            Center(child: Text('Timeline View', style: AppTextStyles.headline)),
            // Archive Tab (placeholder)
            Center(child: Text('Archive View', style: AppTextStyles.headline)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkIndigo,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Timeline'),
          BottomNavigationBarItem(icon: Icon(Icons.archive), label: 'Archive'),
        ],
      ),
    );
  }
} 
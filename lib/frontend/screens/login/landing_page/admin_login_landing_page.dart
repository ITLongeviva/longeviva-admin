import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../backend/bloc/admin_auth_bloc.dart';
import '../../../../backend/controllers/admin_controller.dart';
import '../../../../shared/utils/colors.dart';
import '../widgets/admin_login_form.dart';

class AdminLoginLandingPage extends StatefulWidget {
  const AdminLoginLandingPage({super.key});

  @override
  State<AdminLoginLandingPage> createState() => _AdminLoginLandingPageState();
}

class _AdminLoginLandingPageState extends State<AdminLoginLandingPage> {
  bool _isRedirecting = false;

  @override
  Widget build(BuildContext context) {
    // Provide AdminAuthBloc to this screen
    return BlocProvider<AdminAuthBloc>(
      create: (context) => AdminAuthBloc(
        adminController: AdminController(),
      ),
      child: Builder(
          builder: (context) {
            return BlocListener<AdminAuthBloc, AdminAuthState>(
              listener: (context, state) {
                if (state is AdminAuthAuthenticated && !_isRedirecting) {
                  _isRedirecting = true;

                  // Use microtask to avoid build issues
                  Future.microtask(() {
                    Navigator.of(context).pushReplacementNamed('/admin_dashboard');
                    _isRedirecting = false;
                  });
                }
              },
              child: Scaffold(
                body: Stack(
                  children: [
                    /// Background image
                    Positioned.fill(
                      child: Opacity(
                        opacity: 1,
                        child: SvgPicture.asset('assets/images/background.svg', fit: BoxFit.cover),
                      ),
                    ),

                    /// Page content
                    Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 18),

                              /// Logo with admin badge
                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  // Logo
                                  Container(
                                    margin: const EdgeInsets.only(left: 35),
                                    child: SvgPicture.asset(
                                      width: 120,
                                      'assets/icons/logo/longeviva_logo_with_subtitle.svg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Admin badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: CustomColors.verdeAbisso,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            spreadRadius: 2,
                                            blurRadius: 5,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              /// Login form card with admin theme
                              Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                color: CustomColors.verdeAbisso.withOpacity(0.8), // Admin theme color
                                child: Container(
                                  width: MediaQuery.of(context).size.width > 800
                                      ? 400
                                      : MediaQuery.of(context).size.width * 0.9,
                                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                                  child: BlocBuilder<AdminAuthBloc, AdminAuthState>(
                                    builder: (context, state) {
                                      // If in initial state, trigger check
                                      if (state is AdminAuthInitial) {
                                        context.read<AdminAuthBloc>().add(CheckAdminAuthStatus());
                                      }

                                      // Display a loading indicator if checking auth status
                                      if (state is AdminAuthLoading) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        );
                                      }

                                      return const AdminLoginForm();
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              /// Footer: Copyright and links
                              Column(
                                children: [
                                  const Text(
                                    '© 2025 Longeviva. All rights reserved.',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          // TODO: Navigate to Terms of Service
                                        },
                                        child: const Text(
                                          'Terms of Service',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 14,
                                            color: CustomColors.verdeAbisso,
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        '|',
                                        style: TextStyle(
                                          color: Colors.black38,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          // TODO: Navigate to Privacy Policy
                                        },
                                        child: const Text(
                                          'Privacy Policy',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 14,
                                            color: CustomColors.verdeAbisso,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'home.dart';
import 'providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _showLogo = false;
  bool _showText = false;
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();

    // Configurar las animaciones
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Mostrar elementos con retraso para una animación secuencial
    Timer(const Duration(milliseconds: 300), () {
      setState(() => _showLogo = true);

      Timer(const Duration(milliseconds: 1000), () {
        setState(() => _showText = true);

        Timer(const Duration(milliseconds: 800), () {
          setState(() => _showProgress = true);

          // Navegar a la pantalla Home después de 2 segundos más
          Timer(const Duration(milliseconds: 2000), () {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutQuart;

                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(position: offsetAnimation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          });
        });
      });
    });

    // Iniciar la animación
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
              const Color(0xFF272B4A),
              const Color(0xFF0D1117)
            ]
                : [
              const Color(0xFFE3F2FD),
              const Color(0xFFBBDEFB)
            ],
          ),
        ),
        child: SafeArea(
          child: isLandscape
              ? _buildLandscapeSplash(theme, isDarkMode)
              : _buildPortraitSplash(theme, isDarkMode),
        ),
      ),
    );
  }

  Widget _buildPortraitSplash(ThemeData theme, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo animado
          AnimatedOpacity(
            opacity: _showLogo ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeIn,
            child: AnimatedScale(
              scale: _showLogo ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              child: Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: FittedBox(
                    child: Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Texto animado
          AnimatedOpacity(
            opacity: _showText ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeIn,
            child: Column(
              children: [
                Text(
                  'Mantenimiento',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Buses Suray',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Sistema profesional de gestión y mantenimiento de flotas',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // Indicador de progreso
          AnimatedOpacity(
            opacity: _showProgress ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cargando...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeSplash(ThemeData theme, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: AnimatedOpacity(
              opacity: _showLogo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeIn,
              child: AnimatedScale(
                scale: _showLogo ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: FittedBox(
                      child: Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Texto animado
                AnimatedOpacity(
                  opacity: _showText ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeIn,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mantenimiento',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: theme.colorScheme.onBackground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Buses Suray',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sistema profesional de gestión y mantenimiento de flotas',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Indicador de progreso
                AnimatedOpacity(
                  opacity: _showProgress ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Iniciando aplicación...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
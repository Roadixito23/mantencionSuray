import 'package:flutter/material.dart';
import 'dart:async';
import 'home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Configurar la animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    // Iniciar la animación
    _animationController.forward();

    // Navegar a la pantalla Home después de 3 segundos
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isLandscape ? _buildLandscapeSplash() : _buildPortraitSplash(),
      ),
    );
  }

  Widget _buildPortraitSplash() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo con animación de fade in y scale
        FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: _animation,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.directions_bus,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        // Texto de la aplicación
        FadeTransition(
          opacity: _animation,
          child: const Text(
            'Mantenimiento Buses Suray',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 50),
        // Indicador de carga circular
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ],
    );
  }

  Widget _buildLandscapeSplash() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo con animación de fade in y scale
        FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: _animation,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 30),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Texto de la aplicación
            FadeTransition(
              opacity: _animation,
              child: const Text(
                'Mantenimiento Buses Suray',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Indicador de carga circular
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ],
    );
  }
}
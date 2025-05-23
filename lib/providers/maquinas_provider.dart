// lib/providers/maquinas_provider.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class MaquinasProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _maquinas = [];
  bool _cargando = true;
  bool _sincronizando = false;
  bool _hayConexion = true;

  // Getters
  List<Map<String, dynamic>> get maquinas => _maquinas;
  bool get cargando => _cargando;
  bool get sincronizando => _sincronizando;
  bool get hayConexion => _hayConexion;

  // Constructor
  MaquinasProvider() {
    _inicializar();
  }

  // Inicializar provider
  Future<void> _inicializar() async {
    _cargando = true;
    notifyListeners();

    // Verificar conectividad
    _hayConexion = await _firebaseService.verificarConectividad();

    // Suscribirse al stream de máquinas
    _firebaseService.maquinasStream.listen((maquinasActualizadas) {
      _maquinas = maquinasActualizadas;
      _cargando = false;
      notifyListeners();
    });

    // Intentar sincronizar datos si hay conexión
    if (_hayConexion) {
      await sincronizarDatos();
    }

    _cargando = false;
    notifyListeners();
  }

  // Sincronizar datos
  Future<void> sincronizarDatos() async {
    if (_sincronizando) return;

    _sincronizando = true;
    notifyListeners();

    try {
      await _firebaseService.sincronizarDatos();
      _hayConexion = true;
    } catch (e) {
      _hayConexion = false;
      print('Error al sincronizar datos: $e');
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  // Agregar máquina
  Future<void> agregarMaquina(Map<String, dynamic> maquina) async {
    try {
      if (_hayConexion) {
        // Agregar a Firebase
        String docId = await _firebaseService.agregarMaquina(maquina);
        maquina['docId'] = docId;
      } else {
        // Solo agregar localmente si no hay conexión
        _maquinas.add(maquina);
        notifyListeners();
      }
    } catch (e) {
      print('Error al agregar máquina: $e');
      throw e;
    }
  }

  // Actualizar máquina
  Future<void> actualizarMaquina(Map<String, dynamic> maquina) async {
    try {
      if (_hayConexion && maquina['docId'] != null) {
        // Actualizar en Firebase
        await _firebaseService.actualizarMaquina(maquina);
      } else {
        // Actualizar localmente si no hay conexión
        int index = _maquinas.indexWhere((m) => m['id'] == maquina['id']);
        if (index != -1) {
          _maquinas[index] = maquina;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error al actualizar máquina: $e');
      throw e;
    }
  }

  // Eliminar máquina
  Future<void> eliminarMaquina(Map<String, dynamic> maquina) async {
    try {
      if (_hayConexion && maquina['docId'] != null) {
        // Eliminar de Firebase
        await _firebaseService.eliminarMaquina(maquina['docId']);
      } else {
        // Eliminar localmente si no hay conexión
        _maquinas.removeWhere((m) => m['id'] == maquina['id']);
        notifyListeners();
      }
    } catch (e) {
      print('Error al eliminar máquina: $e');
      throw e;
    }
  }

  // Verificar conexión
  Future<void> verificarConexion() async {
    bool conexionAnterior = _hayConexion;
    _hayConexion = await _firebaseService.verificarConectividad();

    // Si ahora hay conexión pero antes no, sincronizar datos
    if (_hayConexion && !conexionAnterior) {
      await sincronizarDatos();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _firebaseService.dispose();
    super.dispose();
  }
}
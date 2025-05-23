import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FirebaseService {
  // Instancia de Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Referencia a la colección de máquinas
  CollectionReference get maquinasCollection => _firestore.collection('maquinas');

  // Stream controller para emitir actualizaciones de máquinas
  final StreamController<List<Map<String, dynamic>>> _maquinasController =
  StreamController<List<Map<String, dynamic>>>.broadcast();

  // Stream para escuchar cambios en las máquinas
  Stream<List<Map<String, dynamic>>> get maquinasStream => _maquinasController.stream;

  // Constructor
  FirebaseService() {
    // Iniciar escucha a cambios en Firestore
    _iniciarEscuchaFirestore();
  }

  // Método para iniciar la escucha a cambios en Firestore
  void _iniciarEscuchaFirestore() {
    maquinasCollection.snapshots().listen((snapshot) {
      List<Map<String, dynamic>> maquinas = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> maquina = doc.data() as Map<String, dynamic>;
        // Asegurar que el docId esté presente
        maquina['docId'] = doc.id;
        maquinas.add(maquina);
      }

      // Emitir las máquinas actualizadas a través del stream
      _maquinasController.add(maquinas);

      // También actualizar el almacenamiento local
      _guardarMaquinasLocalmente(maquinas);
    }, onError: (error) {
      print('Error al escuchar cambios en Firestore: $error');
    });
  }

  // Método para agregar una nueva máquina
  Future<String> agregarMaquina(Map<String, dynamic> maquina) async {
    try {
      // Agregar timestamp de creación y modificación
      maquina['fechaCreacion'] = Timestamp.now();
      maquina['fechaModificacion'] = Timestamp.now();

      // Agregar a Firestore
      DocumentReference docRef = await maquinasCollection.add(maquina);

      // Actualizar el docId en la máquina y en Firestore
      String docId = docRef.id;
      await docRef.update({'docId': docId});

      return docId;
    } catch (e) {
      print('Error al agregar máquina: $e');
      throw e;
    }
  }

  // Método para actualizar una máquina existente
  Future<void> actualizarMaquina(Map<String, dynamic> maquina) async {
    try {
      // Verificar que tenga docId
      if (maquina['docId'] == null) {
        throw Exception('La máquina no tiene docId');
      }

      // Actualizar timestamp de modificación
      maquina['fechaModificacion'] = Timestamp.now();

      // Actualizar en Firestore
      await maquinasCollection.doc(maquina['docId']).update(maquina);
    } catch (e) {
      print('Error al actualizar máquina: $e');
      throw e;
    }
  }

  // Método para eliminar una máquina
  Future<void> eliminarMaquina(String docId) async {
    try {
      await maquinasCollection.doc(docId).delete();
    } catch (e) {
      print('Error al eliminar máquina: $e');
      throw e;
    }
  }

  // Método para sincronizar datos locales con Firestore
  Future<void> sincronizarDatos() async {
    try {
      // Obtener máquinas locales
      List<Map<String, dynamic>> maquinasLocales = await _cargarMaquinasLocalmente();

      // Obtener máquinas de Firestore
      QuerySnapshot snapshot = await maquinasCollection.get();
      List<Map<String, dynamic>> maquinasFirestore = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> maquina = doc.data() as Map<String, dynamic>;
        maquina['docId'] = doc.id;
        maquinasFirestore.add(maquina);
      }

      // Sincronizar máquinas locales que no están en Firestore
      for (var maquinaLocal in maquinasLocales) {
        // Si la máquina local no tiene docId, es nueva para Firestore
        if (maquinaLocal['docId'] == null) {
          await agregarMaquina(maquinaLocal);
          continue;
        }

        // Verificar si la máquina local existe en Firestore
        bool existeEnFirestore = maquinasFirestore.any(
                (m) => m['docId'] == maquinaLocal['docId']
        );

        if (!existeEnFirestore) {
          // Si no existe en Firestore pero tiene docId, intentar recuperarla
          try {
            await maquinasCollection.doc(maquinaLocal['docId']).set(maquinaLocal);
          } catch (e) {
            print('Error al recuperar máquina en Firestore: $e');
            // Crear una nueva entrada si no se puede recuperar
            maquinaLocal.remove('docId');
            await agregarMaquina(maquinaLocal);
          }
        }
      }

      // Actualizar máquinas locales con datos de Firestore
      await _guardarMaquinasLocalmente(maquinasFirestore);
    } catch (e) {
      print('Error al sincronizar datos: $e');
      throw e;
    }
  }

  // Método para cargar máquinas del almacenamiento local
  Future<List<Map<String, dynamic>>> _cargarMaquinasLocalmente() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/maquinas.json');

      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);
        return maquinasJson.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error al cargar máquinas localmente: $e');
      return [];
    }
  }

  // Método para guardar máquinas en el almacenamiento local
  Future<void> _guardarMaquinasLocalmente(List<Map<String, dynamic>> maquinas) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/maquinas.json');

      final jsonString = jsonEncode(maquinas);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error al guardar máquinas localmente: $e');
    }
  }

  // Método para verificar la conectividad
  Future<bool> verificarConectividad() async {
    try {
      await _firestore.collection('test').doc('test').get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Cerrar recursos al finalizar
  void dispose() {
    _maquinasController.close();
  }
}
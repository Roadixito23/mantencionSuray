import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class CustomDocumentHandler {
  // Formato de fecha para el nombre del archivo
  static final DateFormat _dateFormatter = DateFormat('yyyyMMdd_HHmmss');

  // Nombre del archivo de datos local
  static const String _dataFileName = 'maquinas.json';

  // Extensión de archivo personalizada
  static const String _fileExtension = 'suray';

  // Cargar datos desde el archivo local
  static Future<List<Map<String, dynamic>>> cargarDatosLocales() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_dataFileName');

      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> datosJson = jsonDecode(contenido);
        return datosJson.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error al cargar datos locales: $e');
      return [];
    }
  }

  // Guardar datos al archivo local
  static Future<bool> guardarDatosLocales(List<Map<String, dynamic>> datos) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_dataFileName');

      final jsonString = jsonEncode(datos);
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      print('Error al guardar datos locales: $e');
      return false;
    }
  }

  // Exportar datos a un documento personalizado
  static Future<String?> exportarDocumento(BuildContext context) async {
    try {
      // Cargar datos actuales
      final datos = await cargarDatosLocales();

      if (datos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay datos para exportar'),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }

      // Crear el documento personalizado
      final Map<String, dynamic> documento = {
        'version': '1.0',
        'fecha_exportacion': DateTime.now().toIso8601String(),
        'tipo_documento': 'Suray Backup',
        'datos': datos,
      };

      // Convertir a JSON
      final documentoJson = jsonEncode(documento);

      // Generar nombre de archivo predeterminado
      final timestamp = _dateFormatter.format(DateTime.now());
      final nombreArchivoPredeterminado = 'SurayBackup_$timestamp.$_fileExtension';

      // Abrir selector de archivos para guardar
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo de respaldo',
        fileName: nombreArchivoPredeterminado,
        type: FileType.custom,
        allowedExtensions: [_fileExtension],
      );

      // Si el usuario canceló la operación
      if (outputFile == null) {
        return null;
      }

      // Asegurarnos que el archivo tiene la extensión correcta
      if (!outputFile.endsWith('.$_fileExtension')) {
        outputFile += '.$_fileExtension';
      }

      // Guardar el archivo
      final file = File(outputFile);
      await file.writeAsString(documentoJson);

      return outputFile;
    } catch (e) {
      print('Error al exportar documento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // Importar datos desde un documento personalizado
  static Future<List<Map<String, dynamic>>?> importarDocumento() async {
    try {
      // Abrir selector de archivos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [_fileExtension],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return null;
      }

      // Leer el archivo
      final file = File(result.files.first.path!);
      final contenido = await file.readAsString();

      // Decodificar el documento
      final Map<String, dynamic> documento = jsonDecode(contenido);

      // Verificar que sea un documento válido
      if (!documento.containsKey('version') || !documento.containsKey('datos')) {
        throw Exception('El archivo no es un documento de respaldo válido');
      }

      // Extraer datos
      final List<dynamic> datosJson = documento['datos'];
      return datosJson.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error al importar documento: $e');
      return null;
    }
  }

  // Guardar los datos importados
  static Future<bool> guardarDatosImportados(List<Map<String, dynamic>> datos) async {
    try {
      final datosExistentes = await cargarDatosLocales();

      // Map para mantener los datos únicos por ID
      final Map<String, Map<String, dynamic>> mapaUnificado = {};

      // Agregar datos existentes al mapa
      for (var dato in datosExistentes) {
        if (dato.containsKey('id')) {
          mapaUnificado[dato['id'].toString()] = dato;
        }
      }

      // Sobrescribir/agregar datos importados
      for (var dato in datos) {
        if (dato.containsKey('id')) {
          mapaUnificado[dato['id'].toString()] = dato;
        }
      }

      // Convertir mapa de vuelta a lista
      final List<Map<String, dynamic>> datosUnificados = mapaUnificado.values.toList();

      // Guardar en archivo local
      return await guardarDatosLocales(datosUnificados);
    } catch (e) {
      print('Error al guardar datos importados: $e');
      return false;
    }
  }
}
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'excel_generator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class GenerateExcelScreen extends StatefulWidget {
  const GenerateExcelScreen({Key? key}) : super(key: key);

  @override
  _GenerateExcelScreenState createState() => _GenerateExcelScreenState();
}

class _GenerateExcelScreenState extends State<GenerateExcelScreen> {
  List<Map<String, dynamic>> _maquinas = [];
  bool _generando = false;
  String? _rutaArchivoGenerado;
  int _totalFotos = 0;

  @override
  void initState() {
    super.initState();
    _cargarMaquinas();
  }

  // Cargar máquinas desde el almacenamiento local
  Future<void> _cargarMaquinas() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/maquinas.json');

      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);

        final maquinas = maquinasJson.cast<Map<String, dynamic>>();

        // Contar el total de fotos
        int totalFotos = 0;
        for (var maquina in maquinas) {
          if (maquina['fotos'] != null && maquina['fotos'] is List) {
            totalFotos += (maquina['fotos'] as List).length;
          }
        }

        setState(() {
          _maquinas = maquinas;
          _totalFotos = totalFotos;
        });
      }
    } catch (e) {
      print('Error al cargar máquinas: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Generar Excel
  Future<void> _generarExcel() async {
    if (_maquinas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay máquinas para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _generando = true;
      _rutaArchivoGenerado = null;
    });

    try {
      // Usar el generador de Excel actualizado
      final rutaArchivo = await ExcelGenerator.generarExcelMaquinas();

      setState(() {
        _generando = false;
        _rutaArchivoGenerado = rutaArchivo;
      });

      if (rutaArchivo != null) {
        // Obtener la carpeta que contiene el Excel
        final carpetaExcel = path.dirname(rutaArchivo);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel e imágenes guardados en: $carpetaExcel'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Abrir Carpeta',
              onPressed: () {
                _abrirCarpeta(carpetaExcel);
              },
            ),
          ),
        );
      } else {
        // Si es null, podría ser porque el usuario canceló la operación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación cancelada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _generando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para abrir el archivo generado
  Future<void> _abrirArchivo(String rutaArchivo) async {
    final Uri uri = Uri.file(rutaArchivo);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Si no se puede abrir directamente, mostrar un mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se puede abrir el archivo: $rutaArchivo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para abrir la carpeta que contiene el archivo
  Future<void> _abrirCarpeta(String rutaCarpeta) async {
    final Uri uri = Uri.directory(rutaCarpeta);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Si no se puede abrir directamente, mostrar un mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se puede abrir la carpeta: $rutaCarpeta'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar a Excel'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.insert_drive_file,
                size: 100,
                color: Colors.green.shade300,
              ),
              const SizedBox(height: 20),
              const Text(
                'Exportar Datos de Máquinas a Excel',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Total de Máquinas: ${_maquinas.length}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                'Total de Fotos Adjuntas: $_totalFotos',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Esta función exportará la información de todas las máquinas a un archivo Excel y guardará las imágenes adjuntas en una carpeta separada. Seleccione una carpeta donde guardar todos los archivos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _generando ? null : _generarExcel,
                icon: _generando
                    ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
                    : const Icon(Icons.download),
                label: Text(_generando ? 'Generando...' : 'Generar Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_rutaArchivoGenerado != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Archivos guardados en: ${path.dirname(_rutaArchivoGenerado!)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _abrirArchivo(_rutaArchivoGenerado!),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Abrir Excel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _abrirCarpeta(path.dirname(_rutaArchivoGenerado!)),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Abrir Carpeta'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
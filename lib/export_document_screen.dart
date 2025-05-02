import 'package:flutter/material.dart';
import 'custom_document_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ExportDocumentScreen extends StatefulWidget {
  const ExportDocumentScreen({Key? key}) : super(key: key);

  @override
  _ExportDocumentScreenState createState() => _ExportDocumentScreenState();
}

class _ExportDocumentScreenState extends State<ExportDocumentScreen> {
  List<Map<String, dynamic>> _maquinas = [];
  bool _generando = false;
  String? _rutaArchivoGenerado;

  @override
  void initState() {
    super.initState();
    _cargarMaquinas();
  }

  // Cargar máquinas desde el almacenamiento local
  Future<void> _cargarMaquinas() async {
    final datos = await CustomDocumentHandler.cargarDatosLocales();
    setState(() {
      _maquinas = datos;
    });
  }

  // Exportar documento
  Future<void> _exportarDocumento() async {
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
      final rutaArchivo = await CustomDocumentHandler.exportarDocumento(context);

      setState(() {
        _generando = false;
        _rutaArchivoGenerado = rutaArchivo;
      });

      if (rutaArchivo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento guardado en: $rutaArchivo'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () {
                _abrirArchivo(rutaArchivo);
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
          content: Text('Error al generar documento: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar Documento'),
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
                Icons.save_alt,
                size: 100,
                color: Colors.blue.shade300,
              ),
              const SizedBox(height: 20),
              const Text(
                'Exportar Datos de Máquinas',
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
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  'Esta función permite exportar todos los datos a un archivo de respaldo (.suray) que podrás guardar en tu dispositivo y restaurar posteriormente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _generando ? null : _exportarDocumento,
                icon: _generando
                    ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
                    : const Icon(Icons.download),
                label: Text(_generando ? 'Generando...' : 'Exportar Documento'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_rutaArchivoGenerado != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Archivo guardado en: $_rutaArchivoGenerado',
                  style: const TextStyle(
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _abrirArchivo(_rutaArchivoGenerado!),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir archivo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
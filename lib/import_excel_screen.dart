import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
// Importar Excel con alias para evitar conflictos
import 'package:excel/excel.dart' as excel_lib;
import 'package:permission_handler/permission_handler.dart';

class ImportExcelScreen extends StatefulWidget {
  const ImportExcelScreen({Key? key}) : super(key: key);

  @override
  _ImportExcelScreenState createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends State<ImportExcelScreen> {
  bool _importando = false;
  bool _archivoSeleccionado = false;
  String? _rutaArchivoSeleccionado;
  List<Map<String, dynamic>> _maquinasImportadas = [];
  bool _mostrarVistaPrevia = false;

  @override
  void initState() {
    super.initState();
  }

  // Seleccionar archivo Excel
  Future<void> _seleccionarArchivo() async {
    try {
      // Verificar permisos en Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
          status = await Permission.storage.status;
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se necesitan permisos de almacenamiento para continuar'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }

      // Abrir selector de archivos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _rutaArchivoSeleccionado = result.files.first.path;
          _archivoSeleccionado = true;
          _mostrarVistaPrevia = false;
          _maquinasImportadas = [];
        });

        // Pre-visualizar los datos
        await _preVisualizarExcel();
      }
    } catch (e) {
      print('Error al seleccionar archivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Pre-visualizar datos del Excel
  Future<void> _preVisualizarExcel() async {
    if (_rutaArchivoSeleccionado == null) return;

    setState(() {
      _importando = true;
    });

    try {
      List<Map<String, dynamic>> maquinasExcel = await _leerDatosExcel(_rutaArchivoSeleccionado!);

      setState(() {
        _maquinasImportadas = maquinasExcel;
        _mostrarVistaPrevia = true;
        _importando = false;
      });

      if (_maquinasImportadas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron datos válidos en el archivo Excel'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _importando = false;
        _mostrarVistaPrevia = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al leer el archivo Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Leer datos desde el archivo Excel
  Future<List<Map<String, dynamic>>> _leerDatosExcel(String rutaArchivo) async {
    List<Map<String, dynamic>> maquinasExcel = [];

    try {
      var bytes = File(rutaArchivo).readAsBytesSync();
      var excel = excel_lib.Excel.decodeBytes(bytes);

      // Buscar la hoja de Máquinas
      var sheet = excel.tables['Máquinas'];
      if (sheet == null) {
        // Intentar con la primera hoja si no encuentra una específica
        if (excel.tables.isNotEmpty) {
          sheet = excel.tables.values.first;
        } else {
          throw Exception('No hay hojas en el archivo Excel');
        }
      }

      // Obtener cabeceras (primera fila)
      List<String> headers = [];
      for (var cell in sheet.rows[0]) {
        if (cell?.value != null) {
          headers.add(cell!.value.toString());
        }
      }

      // Procesar filas (desde la segunda fila)
      for (var i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        Map<String, dynamic> maquina = {};

        // Validar que la fila tenga datos
        bool rowHasData = false;
        for (var cell in row) {
          if (cell?.value != null) {
            rowHasData = true;
            break;
          }
        }
        if (!rowHasData) continue;

        // Procesar cada celda de la fila
        for (var j = 0; j < headers.length && j < row.length; j++) {
          var cell = row[j];
          if (cell?.value != null) {
            String header = headers[j];
            String value = cell!.value.toString();

            // Manejar campos especiales
            if (header == 'ID' || header == 'id') {
              maquina['id'] = value;
            } else if (header == 'Patente' || header == 'patente') {
              maquina['patente'] = value.toUpperCase();
            } else if (header == 'Modelo' || header == 'modelo') {
              maquina['modelo'] = value;
            } else if (header.contains('Capacidad')) {
              maquina['capacidad'] = int.tryParse(value) ?? 0;
            } else if (header.contains('Kilometraje')) {
              maquina['kilometraje'] = int.tryParse(value) ?? 0;
            } else if (header.contains('BIN')) {
              maquina['bin'] = value;
            } else if (header.contains('Estado')) {
              maquina['estado'] = value;
            } else if (header.contains('Revisión Técnica')) {
              maquina['fechaRevisionTecnica'] = _parsearFecha(value);
            } else if (header.contains('Filtro Aceite') && header.contains('Fecha')) {
              maquina['fechaCambioFiltroAceite'] = _parsearFecha(value);
            } else if (header.contains('Filtro Aire') && header.contains('Fecha')) {
              maquina['fechaCambioFiltroAire'] = _parsearFecha(value);
            } else if (header.contains('Filtro Petróleo') && header.contains('Fecha')) {
              maquina['fechaCambioFiltroPetroleo'] = _parsearFecha(value);
            } else if (header.contains('Decantador') && header.contains('Fecha')) {
              maquina['fechaRevisionDecantador'] = _parsearFecha(value);
            } else if (header.contains('Correa') && header.contains('Fecha')) {
              maquina['fechaRevisionCorrea'] = _parsearFecha(value);
            } else if (header.contains('Modelo Filtro Aceite')) {
              maquina['modeloFiltroAceite'] = value;
            } else if (header.contains('Modelo Filtro Aire')) {
              maquina['modeloFiltroAire'] = value;
            } else if (header.contains('Modelo Filtro Petróleo')) {
              maquina['modeloFiltroPetroleo'] = value;
            } else if (header.contains('Modelo Decantador')) {
              maquina['modeloDecantador'] = value;
            } else if (header.contains('Modelo Correa')) {
              maquina['modeloCorrea'] = value;
            } else if (header.contains('Comentarios')) {
              maquina['comentario'] = value;
            }
          }
        }

        // Validar que tenga al menos los campos requeridos: id, patente y modelo
        if (maquina.containsKey('id') && maquina.containsKey('patente') && maquina.containsKey('modelo')) {
          maquinasExcel.add(maquina);
        }
      }
    } catch (e) {
      print('Error al procesar Excel: $e');
      throw Exception('Error al procesar el archivo Excel: $e');
    }

    return maquinasExcel;
  }

  // Parsear fecha en diferentes formatos
  String? _parsearFecha(String valor) {
    if (valor == 'No registrada' || valor == 'Fecha inválida' || valor.isEmpty) {
      return null;
    }

    try {
      // Intentar diferentes formatos de fecha
      DateTime? fecha;

      // Formato dd/MM/yyyy
      if (valor.contains('/')) {
        List<String> partes = valor.split('/');
        if (partes.length == 3) {
          int dia = int.parse(partes[0]);
          int mes = int.parse(partes[1]);
          int anio = int.parse(partes[2]);
          fecha = DateTime(anio, mes, dia);
        }
      }
      // Formato ISO o similar
      else {
        fecha = DateTime.parse(valor);
      }

      if (fecha != null) {
        return fecha.toIso8601String();
      }
    } catch (e) {
      print('Error al parsear fecha: $valor - $e');
    }
    return null;
  }

  // Guardar datos importados
  Future<void> _importarDatos() async {
    if (_maquinasImportadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos para importar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _importando = true;
    });

    try {
      // Leer archivo existente (si existe)
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/maquinas.json');

      List<Map<String, dynamic>> maquinasExistentes = [];
      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);
        maquinasExistentes = maquinasJson.cast<Map<String, dynamic>>();
      }

      // Combinar datos (actualizar existentes o agregar nuevos)
      for (var maquinaNueva in _maquinasImportadas) {
        int index = maquinasExistentes.indexWhere((m) => m['id'] == maquinaNueva['id']);
        if (index >= 0) {
          maquinasExistentes[index] = maquinaNueva; // Actualizar
        } else {
          maquinasExistentes.add(maquinaNueva); // Agregar nuevo
        }
      }

      // Guardar al archivo
      final jsonString = jsonEncode(maquinasExistentes);
      await file.writeAsString(jsonString);

      setState(() {
        _importando = false;
        _archivoSeleccionado = false;
        _rutaArchivoSeleccionado = null;
        _maquinasImportadas = [];
        _mostrarVistaPrevia = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_maquinasImportadas.length} máquinas importadas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Regresar a la pantalla anterior después de un breve momento
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context, true); // Regresar con resultado verdadero
      });
    } catch (e) {
      setState(() {
        _importando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar desde Excel'),
        centerTitle: true,
      ),
      body: _importando
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Procesando archivo Excel...'),
          ],
        ),
      )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icono y título
          Icon(
            Icons.upload_file,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Importar Datos desde Excel',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona un archivo Excel previamente exportado para restaurar sus datos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Botón para seleccionar archivo
          ElevatedButton.icon(
            onPressed: _seleccionarArchivo,
            icon: const Icon(Icons.file_open),
            label: const Text('Seleccionar Archivo Excel'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mostrar archivo seleccionado
          if (_archivoSeleccionado && _rutaArchivoSeleccionado != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archivo seleccionado:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rutaArchivoSeleccionado!.split('/').last,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Vista previa de los datos
          if (_mostrarVistaPrevia && _maquinasImportadas.isNotEmpty) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista previa de datos (${_maquinasImportadas.length} máquinas):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _maquinasImportadas.length,
                        itemBuilder: (context, index) {
                          final maquina = _maquinasImportadas[index];
                          return ListTile(
                            title: Text('${maquina['patente']} - ${maquina['modelo']}'),
                            subtitle: Text('ID: ${maquina['id']}'),
                            leading: const Icon(Icons.directions_bus),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _importarDatos,
                    icon: const Icon(Icons.save),
                    label: const Text('Importar Datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Mensaje cuando no hay datos
          if (_mostrarVistaPrevia && _maquinasImportadas.isEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'No se encontraron datos válidos en el archivo seleccionado.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
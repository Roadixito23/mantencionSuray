import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class ExcelGenerator {
  // Método para cargar máquinas desde el archivo JSON
  static Future<List<Map<String, dynamic>>> _cargarMaquinas() async {
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
      print('Error al cargar máquinas: $e');
      return [];
    }
  }

  // Método para generar Excel con todas las máquinas y permitir al usuario elegir dónde guardarlo
  static Future<String?> generarExcelMaquinas() async {
    try {
      // Cargar máquinas
      final maquinas = await _cargarMaquinas();

      if (maquinas.isEmpty) {
        return null;
      }

      // Crear un nuevo archivo Excel
      var excel = Excel.createExcel();
      var sheet = excel['Máquinas'];

      // Definir encabezados
      _agregarEncabezados(sheet);

      // Generar nombre de archivo predeterminado con formato dd/mm/yy
      final dateFormat = DateFormat('dd-MM-yy');
      final nombreArchivoPredeterminado = 'mantenimiento_excel_${dateFormat.format(DateTime.now())}.xlsx';

      // Abrir el selector de directorios para elegir dónde guardar
      String? outputDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccionar carpeta para guardar',
      );

      // Si el usuario canceló la operación
      if (outputDir == null) {
        return null;
      }

      // Crear carpeta de imágenes dentro de la carpeta seleccionada
      final imagenesDir = Directory('$outputDir/imagenes_excel');
      if (!await imagenesDir.exists()) {
        await imagenesDir.create();
      }

      // Procesar imágenes y agregarlas a la carpeta
      Map<String, List<String>> imagenesExportadas = await _exportarImagenes(maquinas, imagenesDir.path);

      // Agregar datos de máquinas con referencias a imágenes
      _agregarDatosMaquinas(sheet, maquinas, imagenesExportadas);

      // Ajustar ancho de columnas
      _ajustarAnchoColumnas(sheet);

      // Ruta completa del archivo Excel
      String outputFile = '$outputDir/$nombreArchivoPredeterminado';

      // Guardar el archivo en la ubicación seleccionada
      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        return outputFile;
      }

      return null;
    } catch (e) {
      print('Error al generar Excel: $e');
      return null;
    }
  }

  // Método para exportar imágenes a la carpeta seleccionada
  static Future<Map<String, List<String>>> _exportarImagenes(
      List<Map<String, dynamic>> maquinas, String carpetaDestino) async {
    Map<String, List<String>> imagenesExportadas = {};

    try {
      for (var maquina in maquinas) {
        if (maquina['fotos'] != null && maquina['fotos'] is List && maquina['fotos'].isNotEmpty) {
          List<String> fotosOriginales = List<String>.from(maquina['fotos']);
          List<String> fotosExportadas = [];

          // Crear subcarpeta para esta máquina
          final idMaquina = maquina['id'] ?? 'maquina';
          final placaMaquina = maquina['placa'] ?? '';
          final carpetaMaquina = '$carpetaDestino/${idMaquina}_$placaMaquina';

          Directory(carpetaMaquina).createSync(recursive: true);

          // Copiar cada imagen
          for (int i = 0; i < fotosOriginales.length; i++) {
            try {
              final fotoOriginal = File(fotosOriginales[i]);
              if (await fotoOriginal.exists()) {
                final nombreArchivo = 'foto_${i + 1}${path.extension(fotosOriginales[i])}';
                final rutaDestino = '$carpetaMaquina/$nombreArchivo';

                await fotoOriginal.copy(rutaDestino);
                fotosExportadas.add(rutaDestino);
              }
            } catch (e) {
              print('Error al copiar imagen: $e');
            }
          }

          if (fotosExportadas.isNotEmpty) {
            imagenesExportadas[maquina['id'].toString()] = fotosExportadas;
          }
        }
      }
    } catch (e) {
      print('Error al exportar imágenes: $e');
    }

    return imagenesExportadas;
  }

  // Método para agregar encabezados
  static void _agregarEncabezados(Sheet sheet) {
    List<String> headers = [
      // Información básica
      'ID',
      'Placa',
      'Modelo',
      'Capacidad',
      'Kilometraje',
      'BIN',
      'Estado',

      // Revisión Técnica
      'Fecha Revisión Técnica',

      // Filtros
      'Modelo Filtro Aceite',
      'Fecha Cambio Filtro Aceite',
      'Modelo Filtro Aire',
      'Fecha Cambio Filtro Aire',
      'Modelo Filtro Petróleo',
      'Fecha Cambio Filtro Petróleo',

      // Otras Revisiones
      'Modelo Decantador',
      'Fecha Revisión Decantador',

      // Correas (hasta 6)
      'Modelo Correa 1',
      'Fecha Revisión Correa 1',
      'Modelo Correa 2',
      'Fecha Revisión Correa 2',
      'Modelo Correa 3',
      'Fecha Revisión Correa 3',
      'Modelo Correa 4',
      'Fecha Revisión Correa 4',
      'Modelo Correa 5',
      'Fecha Revisión Correa 5',
      'Modelo Correa 6',
      'Fecha Revisión Correa 6',

      // Comentarios e imágenes
      'Comentarios',
      'Ruta Imágenes'
    ];

    sheet.appendRow(headers);

    // Dar formato a los encabezados
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: '#E3F2FD',  // Color de fondo azul claro
        horizontalAlign: HorizontalAlign.Center,
      );
    }
  }

  // Método para agregar datos de máquinas
  static void _agregarDatosMaquinas(
      Sheet sheet, List<Map<String, dynamic>> maquinas, Map<String, List<String>> imagenesExportadas) {
    for (var maquina in maquinas) {
      // Obtener las correas con soporte para la nueva estructura
      List<Map<String, dynamic>> correas = _obtenerCorreas(maquina);

      // Obtener ruta de imágenes para esta máquina
      String rutaImagenes = '';
      if (imagenesExportadas.containsKey(maquina['id'].toString())) {
        final carpetaImagenes = path.dirname(imagenesExportadas[maquina['id'].toString()]!.first);
        rutaImagenes = carpetaImagenes;
      }

      List<dynamic> rowData = [
        // Información básica
        maquina['id'] ?? '',
        maquina['placa'] ?? '',
        maquina['modelo'] ?? '',
        maquina['capacidad']?.toString() ?? '',
        maquina['kilometraje']?.toString() ?? '',
        maquina['bin'] ?? '',
        maquina['estado'] ?? '',

        // Revisión Técnica
        _formatearFecha(maquina['fechaRevisionTecnica']),

        // Filtros
        maquina['modeloFiltroAceite'] ?? '',
        _formatearFecha(maquina['fechaCambioFiltroAceite']),
        maquina['modeloFiltroAire'] ?? '',
        _formatearFecha(maquina['fechaCambioFiltroAire']),
        maquina['modeloFiltroPetroleo'] ?? '',
        _formatearFecha(maquina['fechaCambioFiltroPetroleo']),

        // Otras Revisiones
        maquina['modeloDecantador'] ?? '',
        _formatearFecha(maquina['fechaRevisionDecantador']),
      ];

      // Agregar datos de correas (hasta 6)
      for (int i = 0; i < 6; i++) {
        if (i < correas.length) {
          // Agregar modelo de correa
          rowData.add(correas[i]['modelo'] ?? '');
          // Agregar fecha de revisión de correa
          rowData.add(_formatearFecha(correas[i]['fecha']));
        } else {
          // Agregar espacios vacíos para completar hasta 6 correas
          rowData.add('');
          rowData.add('');
        }
      }

      // Comentarios
      rowData.add(maquina['comentario'] ?? '');

      // Ruta de imágenes
      rowData.add(rutaImagenes);

      // Agregar la fila completa al Excel
      sheet.appendRow(rowData);
    }
  }

  // Método para obtener la lista de correas de una máquina
  static List<Map<String, dynamic>> _obtenerCorreas(Map<String, dynamic> maquina) {
    // Verificar si existe la nueva estructura de correas
    if (maquina['correas'] != null && maquina['correas'] is List) {
      try {
        return List<Map<String, dynamic>>.from(maquina['correas']);
      } catch (e) {
        print('Error al procesar correas: $e');
      }
    }

    // Compatibilidad con versión anterior (una sola correa)
    if (maquina['modeloCorrea'] != null) {
      return [{
        'modelo': maquina['modeloCorrea'],
        'fecha': maquina['fechaRevisionCorrea'],
      }];
    }

    return [];
  }

  // Método para ajustar ancho de columnas
  static void _ajustarAnchoColumnas(Sheet sheet) {
    // La biblioteca Excel no permite ajustar fácilmente el ancho de columnas
    // Sin embargo, podemos definir una numeración de columnas para hacerlas más legibles
    int colNum = 0;

    // Grupo: Información básica (columnas 0-6)
    for (int i = 0; i <= 6; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = "${colNum + 1}. ${cell.value.toString()}";
      colNum++;
    }

    // Grupo: Revisión Técnica (columna 7)
    var cellRT = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0));
    cellRT.value = "${colNum + 1}. ${cellRT.value.toString()}";
    colNum++;

    // Grupo: Filtros (columnas 8-13)
    for (int i = 8; i <= 13; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = "${colNum + 1}. ${cell.value.toString()}";
      colNum++;
    }

    // Grupo: Decantador (columnas 14-15)
    for (int i = 14; i <= 15; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = "${colNum + 1}. ${cell.value.toString()}";
      colNum++;
    }

    // Grupo: Correas (columnas 16-27)
    for (int i = 16; i <= 27; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = "${colNum + 1}. ${cell.value.toString()}";
      colNum++;
    }

    // Comentarios y ruta de imágenes (columnas 28-29)
    var cellComentario = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 28, rowIndex: 0));
    cellComentario.value = "${colNum + 1}. ${cellComentario.value.toString()}";
    colNum++;

    var cellImagenes = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 29, rowIndex: 0));
    cellImagenes.value = "${colNum + 1}. ${cellImagenes.value.toString()}";
  }

  // Método para formatear fecha
  static String _formatearFecha(String? fechaIso) {
    if (fechaIso == null || fechaIso.isEmpty) {
      return 'No registrada';
    }
    try {
      final DateTime fecha = DateTime.parse(fechaIso);
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
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
      Map<String, String> imagenesExportadas = await _exportarImagenes(maquinas, imagenesDir.path);

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
  static Future<Map<String, String>> _exportarImagenes(
      List<Map<String, dynamic>> maquinas, String carpetaDestino) async {
    Map<String, String> imagenesExportadas = {};

    try {
      for (var maquina in maquinas) {
        if (maquina['imagenMaquina'] != null && File(maquina['imagenMaquina']).existsSync()) {
          final String imagenOriginal = maquina['imagenMaquina'];

          // Crear nombre único para la imagen
          final idMaquina = maquina['id'] ?? 'maquina';
          final numeroMaquina = maquina['numeroMaquina'] ?? '';
          final extension = path.extension(imagenOriginal);
          final nombreArchivo = 'maquina_${idMaquina}_${numeroMaquina}${extension}';
          final rutaDestino = '$carpetaDestino/$nombreArchivo';

          try {
            final fotoOriginal = File(imagenOriginal);
            if (await fotoOriginal.exists()) {
              await fotoOriginal.copy(rutaDestino);
              imagenesExportadas[maquina['id'].toString()] = rutaDestino;
            }
          } catch (e) {
            print('Error al copiar imagen: $e');
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
      'ID Interno',
      'Número de Máquina',
      'Patente',
      'Modelo',
      'Capacidad',
      'Kilometraje',
      'VIN',
      'Estado',

      // Revisión Técnica
      'Fecha Revisión Técnica',

      // Elementos de Mantenimiento (hasta 10)
      'Mantenimiento 1 - Título',
      'Mantenimiento 1 - Descripción',
      'Mantenimiento 1 - Fecha',
      'Mantenimiento 2 - Título',
      'Mantenimiento 2 - Descripción',
      'Mantenimiento 2 - Fecha',
      'Mantenimiento 3 - Título',
      'Mantenimiento 3 - Descripción',
      'Mantenimiento 3 - Fecha',
      'Mantenimiento 4 - Título',
      'Mantenimiento 4 - Descripción',
      'Mantenimiento 4 - Fecha',
      'Mantenimiento 5 - Título',
      'Mantenimiento 5 - Descripción',
      'Mantenimiento 5 - Fecha',
      'Mantenimiento 6 - Título',
      'Mantenimiento 6 - Descripción',
      'Mantenimiento 6 - Fecha',
      'Mantenimiento 7 - Título',
      'Mantenimiento 7 - Descripción',
      'Mantenimiento 7 - Fecha',
      'Mantenimiento 8 - Título',
      'Mantenimiento 8 - Descripción',
      'Mantenimiento 8 - Fecha',
      'Mantenimiento 9 - Título',
      'Mantenimiento 9 - Descripción',
      'Mantenimiento 9 - Fecha',
      'Mantenimiento 10 - Título',
      'Mantenimiento 10 - Descripción',
      'Mantenimiento 10 - Fecha',

      // Comentarios e imagen
      'Comentarios',
      'Ruta Imagen'
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
      Sheet sheet, List<Map<String, dynamic>> maquinas, Map<String, String> imagenesExportadas) {
    for (var maquina in maquinas) {
      // Obtener elementos de mantenimiento
      List<Map<String, dynamic>> mantenimiento = _obtenerMantenimiento(maquina);

      // Obtener ruta de imagen para esta máquina
      String rutaImagen = '';
      if (imagenesExportadas.containsKey(maquina['id'].toString())) {
        rutaImagen = imagenesExportadas[maquina['id'].toString()]!;
      }

      List<dynamic> rowData = [
        // Información básica
        maquina['id'] ?? '',
        maquina['numeroMaquina'] ?? '',
        maquina['patente'] ?? '',
        maquina['modelo'] ?? '',
        maquina['capacidad']?.toString() ?? '',
        maquina['kilometraje']?.toString() ?? '',
        maquina['vin'] ?? '',
        maquina['estado'] ?? '',

        // Revisión Técnica
        _formatearFecha(maquina['fechaRevisionTecnica']),
      ];

      // Agregar datos de mantenimiento (hasta 10)
      for (int i = 0; i < 10; i++) {
        if (i < mantenimiento.length) {
          // Agregar título, descripción y fecha del elemento
          rowData.add(mantenimiento[i]['titulo'] ?? '');
          rowData.add(mantenimiento[i]['descripcion'] ?? '');
          rowData.add(_formatearFecha(mantenimiento[i]['fecha']));
        } else {
          // Agregar espacios vacíos para completar hasta 10 elementos
          rowData.add('');
          rowData.add('');
          rowData.add('');
        }
      }

      // Comentarios
      rowData.add(maquina['comentario'] ?? '');

      // Ruta de imagen
      rowData.add(rutaImagen);

      // Agregar la fila completa al Excel
      sheet.appendRow(rowData);
    }
  }

  // Método para obtener la lista de elementos de mantenimiento de una máquina
  static List<Map<String, dynamic>> _obtenerMantenimiento(Map<String, dynamic> maquina) {
    if (maquina['mantenimiento'] != null && maquina['mantenimiento'] is List) {
      try {
        return List<Map<String, dynamic>>.from(maquina['mantenimiento']);
      } catch (e) {
        print('Error al procesar mantenimiento: $e');
      }
    }
    return [];
  }

  // Método para ajustar ancho de columnas
  static void _ajustarAnchoColumnas(Sheet sheet) {
    // La biblioteca Excel no permite ajustar fácilmente el ancho de columnas
    // Sin embargo, podemos definir una numeración de columnas para hacerlas más legibles
    int colNum = 0;

    // Grupo: Información básica (columnas 0-7)
    for (int i = 0; i <= 7; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = "${colNum + 1}. ${cell.value.toString()}";
      colNum++;
    }

    // Grupo: Revisión Técnica (columna 8)
    var cellRT = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0));
    cellRT.value = "${colNum + 1}. ${cellRT.value.toString()}";
    colNum++;

    // Grupo: Mantenimiento (columnas 9-38, 3 columnas por cada elemento de mantenimiento)
    for (int i = 9; i <= 38; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = "${colNum + 1}. ${cell.value.toString()}";
      colNum++;
    }

    // Comentarios e imagen (columnas 39-40)
    var cellComentario = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 39, rowIndex: 0));
    cellComentario.value = "${colNum + 1}. ${cellComentario.value.toString()}";
    colNum++;

    var cellImagen = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 40, rowIndex: 0));
    cellImagen.value = "${colNum + 1}. ${cellImagen.value.toString()}";
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
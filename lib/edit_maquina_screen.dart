import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class EditMaquinaScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? maquinaExistente;

  const EditMaquinaScreen({
    Key? key,
    required this.onSave,
    this.maquinaExistente,
  }) : super(key: key);

  @override
  _EditMaquinaScreenState createState() => _EditMaquinaScreenState();
}

class _EditMaquinaScreenState extends State<EditMaquinaScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController, _placaController, _modeloController,
      _capacidadController, _kilometrajeController, _binController,
      _modeloFiltroAceiteController, _modeloFiltroAireController,
      _modeloFiltroPetroleoController, _modeloDecantadorController,
      _comentarioController;

  // Lista de correas (con modelo y fecha)
  List<Map<String, dynamic>> _correas = [];

  // Lista de fotos adjuntas
  List<String> _fotos = [];

  String _estado = 'Activo';
  DateTime? _fechaRevisionTecnica, _fechaCambioFiltroAceite,
      _fechaCambioFiltroAire, _fechaCambioFiltroPetroleo,
      _fechaRevisionDecantador;

  bool _cargando = false;

  // Colores estándar
  final Color _colorPrimario = Colors.blue;
  final Color _colorAlerta = Colors.red;
  final Color _colorFondo = Colors.white;
  final Color _colorTextoSecundario = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setInitialValues();
    _initializeCorreas();
  }

  void _initializeControllers() {
    _idController = TextEditingController(text: widget.maquinaExistente?['id'] ?? '');
    _placaController = TextEditingController(text: widget.maquinaExistente?['placa'] ?? '');
    _modeloController = TextEditingController(text: widget.maquinaExistente?['modelo'] ?? '');
    _capacidadController = TextEditingController(text: widget.maquinaExistente?['capacidad']?.toString() ?? '');
    _kilometrajeController = TextEditingController(text: widget.maquinaExistente?['kilometraje']?.toString() ?? '');
    _binController = TextEditingController(text: widget.maquinaExistente?['bin'] ?? '');
    _modeloFiltroAceiteController = TextEditingController(text: widget.maquinaExistente?['modeloFiltroAceite'] ?? '');
    _modeloFiltroAireController = TextEditingController(text: widget.maquinaExistente?['modeloFiltroAire'] ?? '');
    _modeloFiltroPetroleoController = TextEditingController(text: widget.maquinaExistente?['modeloFiltroPetroleo'] ?? '');
    _modeloDecantadorController = TextEditingController(text: widget.maquinaExistente?['modeloDecantador'] ?? '');
    _comentarioController = TextEditingController(text: widget.maquinaExistente?['comentario'] ?? '');
  }

  void _setInitialValues() {
    if (widget.maquinaExistente != null) {
      _estado = widget.maquinaExistente!['estado'] ?? _estado;
      _fechaRevisionTecnica = _parseDate(widget.maquinaExistente?['fechaRevisionTecnica']);
      _fechaCambioFiltroAceite = _parseDate(widget.maquinaExistente?['fechaCambioFiltroAceite']);
      _fechaCambioFiltroAire = _parseDate(widget.maquinaExistente?['fechaCambioFiltroAire']);
      _fechaCambioFiltroPetroleo = _parseDate(widget.maquinaExistente?['fechaCambioFiltroPetroleo']);
      _fechaRevisionDecantador = _parseDate(widget.maquinaExistente?['fechaRevisionDecantador']);

      // Cargar fotos si existen
      if (widget.maquinaExistente!['fotos'] != null) {
        _fotos = List<String>.from(widget.maquinaExistente!['fotos']);
      }
    }
  }

  void _initializeCorreas() {
    // Inicializar correas desde datos existentes
    if (widget.maquinaExistente?['correas'] != null) {
      try {
        final List<dynamic> correasData = widget.maquinaExistente!['correas'];
        _correas = correasData.cast<Map<String, dynamic>>();

        // Asegurarse de que cada correa tenga un controlador
        for (var correa in _correas) {
          correa['controller'] = TextEditingController(text: correa['modelo'] ?? '');
        }
      } catch (e) {
        print('Error al cargar correas: $e');
        _correas = [];
      }
    } else if (widget.maquinaExistente?['modeloCorrea'] != null) {
      // Compatibilidad con versión anterior (una sola correa)
      Map<String, dynamic> correaAntigua = {
        'modelo': widget.maquinaExistente!['modeloCorrea'],
        'fecha': widget.maquinaExistente!['fechaRevisionCorrea'],
        'controller': TextEditingController(text: widget.maquinaExistente!['modeloCorrea']),
      };
      _correas = [correaAntigua];
    }

    // Si no hay correas, agregar una vacía
    if (_correas.isEmpty) {
      _agregarCorrea();
    }
  }

  void _agregarCorrea() {
    if (_correas.length < 6) {
      setState(() {
        _correas.add({
          'modelo': '',
          'fecha': null,
          'controller': TextEditingController(),
        });
      });
    }
  }

  // Eliminar una correa
  void _eliminarCorrea(int index) {
    if (_correas.length > 1) {
      setState(() {
        final controllerToDispose = _correas[index]['controller'] as TextEditingController?;
        if (controllerToDispose != null) {
          controllerToDispose.dispose();
        }
        _correas.removeAt(index);
      });
    }
  }

  DateTime? _parseDate(String? dateString) {
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  // Método para calcular si una fecha está próxima a vencerse o vencida
  EstadoFecha _verificarFecha(DateTime? fecha) {
    if (fecha == null) {
      return EstadoFecha.normal;
    }

    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora).inDays;

    if (diferencia < 0) {
      return EstadoFecha.vencida;
    } else if (diferencia <= 30) {
      return EstadoFecha.proxima;
    } else {
      return EstadoFecha.normal;
    }
  }

  // Obtener color según el estado de la fecha
  Color _getColorFecha(DateTime? fecha) {
    final estado = _verificarFecha(fecha);
    switch (estado) {
      case EstadoFecha.vencida:
        return _colorAlerta;
      case EstadoFecha.proxima:
        return Colors.orange;
      case EstadoFecha.normal:
        return _colorPrimario;
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, DateTime? fechaInicial, Function(DateTime) onFechaSeleccionada) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _colorPrimario,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      onFechaSeleccionada(fechaSeleccionada);
    }
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'No establecida';
    }

    // Formatear fecha
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(fecha);
  }

  // Método para seleccionar y agregar fotos
  Future<void> _seleccionarFotos() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Obtener directorio de la aplicación para guardar fotos
        final appDir = await getApplicationDocumentsDirectory();
        final dirPath = '${appDir.path}/fotos_maquinas';

        // Crear directorio si no existe
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Generar ID único para este conjunto de fotos (basado en timestamp)
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        // Guardar cada imagen seleccionada
        for (var file in result.files) {
          if (file.path != null) {
            final sourceFile = File(file.path!);
            final fileName = '${timestamp}_${path.basename(file.path!)}';
            final targetPath = path.join(dirPath, fileName);

            // Copiar archivo al directorio de la aplicación
            await sourceFile.copy(targetPath);

            // Agregar ruta a la lista de fotos
            setState(() {
              _fotos.add(targetPath);
            });
          }
        }

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} fotos agregadas'),
            backgroundColor: _colorPrimario,
          ),
        );
      }
    } catch (e) {
      print('Error al seleccionar fotos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar fotos: $e'),
          backgroundColor: _colorAlerta,
        ),
      );
    }
  }

  // Eliminar una foto
  void _eliminarFoto(int index) {
    setState(() {
      final fotoPath = _fotos[index];
      _fotos.removeAt(index);

      // Intentar eliminar el archivo físico (de manera asíncrona)
      File(fotoPath).delete().catchError((e) {
        print('Error al eliminar archivo: $e');
      });
    });
  }

  // Ver una foto en pantalla completa
  void _verFoto(String fotoPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Visualizar Foto'),
            backgroundColor: _colorPrimario,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(fotoPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 80, color: _colorTextoSecundario),
                      const SizedBox(height: 16),
                      Text('No se pudo cargar la imagen', style: TextStyle(color: _colorTextoSecundario)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _guardarMaquina() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _cargando = true; });

      // Preparar la lista de correas para guardar
      List<Map<String, dynamic>> correasParaGuardar = _correas.map((correa) {
        final TextEditingController? controller = correa['controller'] as TextEditingController?;
        final String modelo = controller?.text ?? correa['modelo'] ?? '';

        return {
          'modelo': modelo,
          'fecha': correa['fecha']?.toIso8601String(),
        };
      }).toList();

      final nuevaMaquina = {
        'id': _idController.text.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString().substring(6) : _idController.text,
        'placa': _placaController.text.toUpperCase(),
        'modelo': _modeloController.text,
        'capacidad': int.tryParse(_capacidadController.text) ?? 0,
        'kilometraje': int.tryParse(_kilometrajeController.text) ?? 0,
        'bin': _binController.text,
        'estado': _estado,
        'modeloFiltroAceite': _modeloFiltroAceiteController.text,
        'modeloFiltroAire': _modeloFiltroAireController.text,
        'modeloFiltroPetroleo': _modeloFiltroPetroleoController.text,
        'modeloDecantador': _modeloDecantadorController.text,
        'fechaRevisionTecnica': _fechaRevisionTecnica?.toIso8601String(),
        'fechaCambioFiltroAceite': _fechaCambioFiltroAceite?.toIso8601String(),
        'fechaCambioFiltroAire': _fechaCambioFiltroAire?.toIso8601String(),
        'fechaCambioFiltroPetroleo': _fechaCambioFiltroPetroleo?.toIso8601String(),
        'fechaRevisionDecantador': _fechaRevisionDecantador?.toIso8601String(),
        'fechaModificacion': DateTime.now().toIso8601String(),
        // Nueva estructura de correas
        'correas': correasParaGuardar,
        // Comentario
        'comentario': _comentarioController.text,
        // Fotos adjuntas
        'fotos': _fotos,
      };

      await _guardarEnStorage(nuevaMaquina);
      widget.onSave(nuevaMaquina);

      setState(() { _cargando = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Máquina guardada exitosamente'),
          backgroundColor: _colorPrimario
      ));
      Navigator.pop(context);
    }
  }

  Future<void> _guardarEnStorage(Map<String, dynamic> nuevaMaquina) async {
    try {
      final file = await _localFile;
      List<Map<String, dynamic>> maquinas = [];

      if (await file.exists()) {
        final contenido = await file.readAsString();
        maquinas = jsonDecode(contenido).cast<Map<String, dynamic>>();

        if (widget.maquinaExistente != null) {
          final index = maquinas.indexWhere((m) => m['id'] == nuevaMaquina['id']);
          if (index != -1) {
            maquinas[index] = nuevaMaquina;
          } else {
            maquinas.add(nuevaMaquina);
          }
        } else {
          maquinas.add(nuevaMaquina);
        }
      } else {
        maquinas.add(nuevaMaquina);
      }

      await file.writeAsString(jsonEncode(maquinas));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: _colorAlerta
      ));
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/maquinas.json');
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.maquinaExistente != null;
    final titulo = esEdicion ? 'Editar Máquina' : 'Agregar Máquina';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        centerTitle: true,
        backgroundColor: _colorPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: _colorPrimario))
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_colorPrimario.withOpacity(0.05), Colors.white],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIdField(esEdicion),
                _buildPlacaField(),
                _buildModeloField(),
                _buildCapacidadField(),
                _buildKilometrajeField(),
                _buildBinField(),
                _buildDateCard('Revisión Técnica', _fechaRevisionTecnica, _getColorFecha(_fechaRevisionTecnica),
                        (fecha) => setState(() => _fechaRevisionTecnica = fecha)
                ),
                _buildFiltersCard(),
                _buildDecantadorCard(),
                _buildCorreasCard(),
                _buildComentariosCard(),
                _buildStatusDropdown(),
                const SizedBox(height: 40),
                _buildSaveButton(esEdicion),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdField(bool esEdicion) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _idController,
          decoration: InputDecoration(
            labelText: 'ID',
            helperText: _idController.text.isEmpty ? 'Se generará automáticamente si se deja en blanco' : null,
            prefixIcon: Icon(Icons.tag, color: _colorPrimario),
            border: InputBorder.none,
          ),
          enabled: !esEdicion,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPlacaField() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _placaController,
          decoration: InputDecoration(
            labelText: 'Placa * (máx. 6 caracteres)',
            prefixIcon: Icon(Icons.credit_card, color: _colorPrimario),
            border: InputBorder.none,
            counterText: "",
          ),
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          inputFormatters: [
            UpperCaseTextFormatter(),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La placa es obligatoria';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildModeloField() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _modeloController,
          decoration: InputDecoration(
            labelText: 'Modelo *',
            prefixIcon: Icon(Icons.directions_bus, color: _colorPrimario),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El modelo es obligatorio';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildCapacidadField() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _capacidadController,
          decoration: InputDecoration(
            labelText: 'Capacidad de pasajeros',
            prefixIcon: Icon(Icons.people, color: _colorPrimario),
            suffixText: 'pasajeros',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final numero = int.tryParse(value);
              if (numero == null || numero <= 0) {
                return 'Ingrese un número válido mayor a 0';
              }
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildKilometrajeField() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _kilometrajeController,
          decoration: InputDecoration(
            labelText: 'Kilometraje',
            prefixIcon: Icon(Icons.speed, color: _colorPrimario),
            suffixText: 'km',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
      ),
    );
  }

  Widget _buildBinField() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _binController,
          decoration: InputDecoration(
            labelText: 'Número de BIN',
            prefixIcon: Icon(Icons.numbers, color: _colorPrimario),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDateCard(
      String title,
      DateTime? date,
      Color color,
      Function(DateTime) onDateSelected
      ) {
    final estadoFecha = _verificarFecha(date);

    // Iconos y textos según el estado
    IconData statusIcon;
    String statusText = '';
    Color statusColor = color;

    if (estadoFecha == EstadoFecha.vencida) {
      statusIcon = Icons.warning;
      statusText = '¡Revisión vencida!';
      statusColor = _colorAlerta;
    } else if (estadoFecha == EstadoFecha.proxima) {
      statusIcon = Icons.access_time;
      statusText = 'Próxima a vencer';
      statusColor = Colors.orange;
    } else {
      statusIcon = Icons.check_circle;
      statusText = '';
      statusColor = _colorPrimario;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: estadoFecha != EstadoFecha.normal
            ? BorderSide(color: statusColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.safety_check, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (statusText.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha actual:',
                      style: TextStyle(
                        fontSize: 12,
                        color: _colorTextoSecundario,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatearFecha(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _seleccionarFecha(context, date, onDateSelected),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Cambiar fecha'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    // Calcular estados de fechas para filtros
    final colorFiltroAceite = _getColorFecha(_fechaCambioFiltroAceite);
    final colorFiltroAire = _getColorFecha(_fechaCambioFiltroAire);
    final colorFiltroPetroleo = _getColorFecha(_fechaCambioFiltroPetroleo);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  children: [
                    Icon(Icons.filter_alt, color: _colorPrimario),
                    const SizedBox(width: 10),
                    const Text('Mantenimiento de Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]
              ),
              const Divider(height: 24),

              _buildFilterRow(
                  'Filtro de Aceite',
                  _modeloFiltroAceiteController,
                  _fechaCambioFiltroAceite,
                  colorFiltroAceite,
                      (fecha) => setState(() => _fechaCambioFiltroAceite = fecha)
              ),
              const Divider(),

              _buildFilterRow(
                  'Filtro de Aire',
                  _modeloFiltroAireController,
                  _fechaCambioFiltroAire,
                  colorFiltroAire,
                      (fecha) => setState(() => _fechaCambioFiltroAire = fecha)
              ),
              const Divider(),

              _buildFilterRow(
                  'Filtro de Petróleo',
                  _modeloFiltroPetroleoController,
                  _fechaCambioFiltroPetroleo,
                  colorFiltroPetroleo,
                      (fecha) => setState(() => _fechaCambioFiltroPetroleo = fecha)
              ),
            ]
        ),
      ),
    );
  }

  Widget _buildFilterRow(
      String title,
      TextEditingController controller,
      DateTime? date,
      Color color,
      Function(DateTime) onDateSelected
      ) {
    return Row(
      children: [
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      )
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                        labelText: 'Modelo/Referencia',
                        isDense: true
                    ),
                    style: const TextStyle(fontSize: 16),
                  )
                ]
            )
        ),
        const SizedBox(width: 16),
        Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  'Último cambio:',
                  style: TextStyle(
                    fontSize: 12,
                    color: _colorTextoSecundario,
                  )
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _seleccionarFecha(context, date, onDateSelected),
                icon: Icon(Icons.calendar_today, size: 16, color: color),
                label: Text(
                  _formatearFecha(date),
                  style: TextStyle(color: color),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ]
        ),
      ],
    );
  }

  Widget _buildDecantadorCard() {
    // Calcular estado de fechas para decantador
    final colorDecantador = _getColorFecha(_fechaRevisionDecantador);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  children: [
                    Icon(Icons.water_drop, color: _colorPrimario),
                    const SizedBox(width: 10),
                    const Text('Decantador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]
              ),
              const Divider(height: 24),

              _buildFilterRow(
                  'Decantador',
                  _modeloDecantadorController,
                  _fechaRevisionDecantador,
                  colorDecantador,
                      (fecha) => setState(() => _fechaRevisionDecantador = fecha)
              ),
            ]
        ),
      ),
    );
  }

  Widget _buildCorreasCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_input_component, color: _colorPrimario),
                const SizedBox(width: 10),
                const Text(
                  'Correas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_correas.length < 6)
                  TextButton.icon(
                    onPressed: _agregarCorrea,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Correa'),
                    style: TextButton.styleFrom(foregroundColor: _colorPrimario),
                  ),
              ],
            ),
            const Divider(height: 24),

            // Mostrar lista de correas dinámicamente
            ..._correas.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> correa = entry.value;

              // Determinar el color según el estado de la fecha
              DateTime? fechaCorrea;
              if (correa['fecha'] != null) {
                try {
                  fechaCorrea = DateTime.parse(correa['fecha']);
                } catch (e) {
                  print('Error parsing correa date: $e');
                }
              }

              final colorCorrea = _getColorFecha(fechaCorrea);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorCorrea == _colorPrimario
                        ? Colors.grey.shade300
                        : colorCorrea.withOpacity(0.5),
                    width: colorCorrea == _colorPrimario ? 1 : 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Correa ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorCorrea,
                          ),
                        ),
                        const Spacer(),
                        if (_correas.length > 1)
                          IconButton(
                            icon: Icon(Icons.delete, color: _colorAlerta),
                            tooltip: 'Eliminar correa',
                            onPressed: () => _eliminarCorrea(index),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: correa['controller'] as TextEditingController,
                            decoration: const InputDecoration(
                              labelText: 'Modelo/Referencia',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              correa['modelo'] = value;
                            },
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Última revisión',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton.icon(
                              onPressed: () => _seleccionarFecha(
                                context,
                                correa['fecha'] != null ? DateTime.parse(correa['fecha']) : null,
                                    (fecha) => setState(() => correa['fecha'] = fecha.toIso8601String()),
                              ),
                              icon: Icon(Icons.calendar_today, size: 16, color: colorCorrea),
                              label: Text(
                                _formatearFecha(
                                    correa['fecha'] != null ? DateTime.parse(correa['fecha']) : null
                                ),
                                style: TextStyle(color: colorCorrea),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colorCorrea),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Nuevo método para el card de comentarios con adjunto de fotos
  Widget _buildComentariosCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment, color: _colorPrimario),
                const SizedBox(width: 10),
                const Text(
                  'Comentarios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _seleccionarFotos,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Adjuntar Fotos'),
                  style: TextButton.styleFrom(foregroundColor: _colorPrimario),
                ),
              ],
            ),
            const Divider(height: 24),

            // Campo de texto para comentarios
            TextFormField(
              controller: _comentarioController,
              decoration: const InputDecoration(
                hintText: 'Ingrese comentarios sobre la máquina',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              style: const TextStyle(fontSize: 16),
            ),

            // Mostrar fotos adjuntas
            if (_fotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Fotos adjuntas:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              // Grid de miniaturas
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _fotos.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      // Miniatura de la imagen
                      InkWell(
                        onTap: () => _verFoto(_fotos[index]),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_fotos[index]),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Botón para eliminar
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _eliminarFoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonFormField<String>(
          value: _estado,
          decoration: InputDecoration(
            labelText: 'Estado',
            prefixIcon: Icon(Icons.health_and_safety, color: _colorPrimario),
            border: InputBorder.none,
          ),
          items: const [
            DropdownMenuItem(value: 'Activo', child: Text('Activo')),
            DropdownMenuItem(value: 'En mantenimiento', child: Text('En mantenimiento')),
            DropdownMenuItem(value: 'Fuera de servicio', child: Text('Fuera de servicio')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() { _estado = value; });
            }
          },
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool esEdicion) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _guardarMaquina,
        style: ElevatedButton.styleFrom(
            backgroundColor: _colorPrimario,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: _colorPrimario.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        ),
        icon: const Icon(Icons.save),
        label: Text(
            esEdicion ? 'Actualizar Máquina' : 'Guardar Máquina',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }
}

// Formateador de texto para convertir a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Enum para los estados de las fechas
enum EstadoFecha {
  normal,
  proxima,
  vencida
}
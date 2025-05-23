import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Referencia a Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores para Identificación
  late TextEditingController _numeroMaquinaController;
  late TextEditingController _patenteController;
  late TextEditingController _modeloController;
  late TextEditingController _capacidadController;
  late TextEditingController _kilometrajeController;
  late TextEditingController _vinController;

  // Controlador para Comentario
  late TextEditingController _comentarioController;

  // Lista de elementos de mantenimiento
  List<Map<String, dynamic>> _elementosMantenimiento = [];

  // Imagen de la máquina
  String? _imagenMaquina;

  // Estado y Revisión Técnica
  String _estado = 'Activo';
  DateTime? _fechaRevisionTecnica;

  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeMantenimiento();
    _setInitialValues();
  }

  void _initializeControllers() {
    _numeroMaquinaController = TextEditingController(
        text: widget.maquinaExistente?['numeroMaquina'] ?? '');
    _patenteController = TextEditingController(
        text: widget.maquinaExistente?['patente'] ?? '');
    _modeloController = TextEditingController(
        text: widget.maquinaExistente?['modelo'] ?? '');
    _capacidadController = TextEditingController(
        text: widget.maquinaExistente?['capacidad']?.toString() ?? '');
    _kilometrajeController = TextEditingController(
        text: widget.maquinaExistente?['kilometraje']?.toString() ?? '');
    _vinController = TextEditingController(
        text: widget.maquinaExistente?['vin'] ?? '');
    _comentarioController = TextEditingController(
        text: widget.maquinaExistente?['comentario'] ?? '');
  }

  void _initializeMantenimiento() {
    if (widget.maquinaExistente?['mantenimiento'] != null) {
      _elementosMantenimiento = List<Map<String, dynamic>>.from(
          widget.maquinaExistente!['mantenimiento']);

      // Agregar controladores a elementos existentes
      for (var elemento in _elementosMantenimiento) {
        elemento['tituloController'] = TextEditingController(text: (elemento['titulo'] as String?) ?? '');
        elemento['descripcionController'] = TextEditingController(text: (elemento['descripcion'] as String?) ?? '');
      }
    } else {
      // Crear elementos predeterminados
      _crearElementosPredeterminados();
    }
  }

  void _crearElementosPredeterminados() {
    final elementosPredeterminados = [
      {'titulo': 'Filtro de Aire', 'descripcion': '', 'tieneFecha': true},
      {'titulo': 'Filtro de Aceite', 'descripcion': '', 'tieneFecha': true},
      {'titulo': 'Filtro de Petróleo', 'descripcion': '', 'tieneFecha': true},
      {'titulo': 'Correa 1', 'descripcion': '', 'tieneFecha': true},
      {'titulo': 'Correa 2', 'descripcion': '', 'tieneFecha': true},
      {'titulo': 'Correa 3', 'descripcion': '', 'tieneFecha': true},
      {'titulo': 'Decantador', 'descripcion': '', 'tieneFecha': true},
    ];

    for (var elemento in elementosPredeterminados) {
      _elementosMantenimiento.add({
        'titulo': elemento['titulo'],
        'descripcion': elemento['descripcion'],
        'fecha': null,
        'tieneFecha': elemento['tieneFecha'],
        'tituloController': TextEditingController(text: elemento['titulo'] as String),
        'descripcionController': TextEditingController(text: elemento['descripcion'] as String),
      });
    }
  }

  void _setInitialValues() {
    if (widget.maquinaExistente != null) {
      _estado = widget.maquinaExistente!['estado'] ?? _estado;
      _fechaRevisionTecnica = _parseDate(widget.maquinaExistente?['fechaRevisionTecnica']);
      _imagenMaquina = widget.maquinaExistente?['imagenMaquina'];
    }
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      return DateTime.tryParse(dateValue);
    }

    return null;
  }

  void _agregarElementoMantenimiento() {
    setState(() {
      _elementosMantenimiento.add({
        'titulo': '',
        'descripcion': '',
        'fecha': null,
        'tieneFecha': true,
        'tituloController': TextEditingController(),
        'descripcionController': TextEditingController(),
      });
    });
  }

  void _eliminarElementoMantenimiento(int index) {
    if (_elementosMantenimiento.length > 1) {
      setState(() {
        _elementosMantenimiento[index]['tituloController']?.dispose();
        _elementosMantenimiento[index]['descripcionController']?.dispose();
        _elementosMantenimiento.removeAt(index);
      });
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, DateTime? fechaInicial, Function(DateTime) onFechaSeleccionada) async {
    final theme = Theme.of(context);

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
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

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) {
      return 'No establecida';
    }

    DateTime? fechaDateTime;

    if (fecha is DateTime) {
      fechaDateTime = fecha;
    } else if (fecha is Timestamp) {
      fechaDateTime = fecha.toDate();
    } else if (fecha is String) {
      try {
        fechaDateTime = DateTime.parse(fecha);
      } catch (e) {
        return 'Fecha inválida';
      }
    } else {
      return 'No establecida';
    }

    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(fechaDateTime);
  }

  Future<void> _seleccionarImagen() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.first.path != null) {
        // Obtener directorio de la aplicación para guardar imagen
        final appDir = await getApplicationDocumentsDirectory();
        final dirPath = '${appDir.path}/imagenes_maquinas';

        // Crear directorio si no existe
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Generar nombre único para la imagen
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final extension = path.extension(result.files.first.path!);
        final fileName = 'maquina_${timestamp}${extension}';
        final targetPath = path.join(dirPath, fileName);

        // Copiar archivo al directorio de la aplicación
        final sourceFile = File(result.files.first.path!);
        await sourceFile.copy(targetPath);

        setState(() {
          _imagenMaquina = targetPath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen agregada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _eliminarImagen() {
    setState(() {
      if (_imagenMaquina != null) {
        // Intentar eliminar el archivo físico
        File(_imagenMaquina!).delete().catchError((e) {
          print('Error al eliminar archivo: $e');
        });
        _imagenMaquina = null;
      }
    });
  }

  void _verImagen() {
    if (_imagenMaquina != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Imagen de la Máquina'),
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_imagenMaquina!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text('No se pudo cargar la imagen'),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  String _generarIdUnico() {
    // Generar ID numérico de 6 dígitos
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 900000) + 100000; // Asegurar 6 dígitos
    return random.toString();
  }

  void _guardarMaquina() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _cargando = true; });

      try {
        // Preparar elementos de mantenimiento para guardar
        List<Map<String, dynamic>> mantenimientoParaGuardar = _elementosMantenimiento.map((elemento) {
          return {
            'titulo': elemento['tituloController']?.text ?? '',
            'descripcion': elemento['descripcionController']?.text ?? '',
            'fecha': elemento['fecha'],
            'tieneFecha': elemento['tieneFecha'] ?? true,
          };
        }).toList();

        final nuevaMaquina = {
          // ID interno (6 dígitos)
          'id': widget.maquinaExistente?['id'] ?? _generarIdUnico(),

          // Identificación
          'numeroMaquina': _numeroMaquinaController.text,
          'patente': _patenteController.text.toUpperCase(),
          'modelo': _modeloController.text,
          'capacidad': int.tryParse(_capacidadController.text) ?? 0,
          'kilometraje': int.tryParse(_kilometrajeController.text) ?? 0,
          'vin': _vinController.text.toUpperCase(),

          // Mantenimiento
          'mantenimiento': mantenimientoParaGuardar,

          // Comentario e imagen
          'comentario': _comentarioController.text,
          'imagenMaquina': _imagenMaquina,

          // Estado y revisión técnica
          'estado': _estado,
          'fechaRevisionTecnica': _fechaRevisionTecnica,

          // Metadatos
          'fechaCreacion': widget.maquinaExistente?['fechaCreacion'] ?? Timestamp.now(),
          'fechaModificacion': Timestamp.now(),
        };

        // Guardar en Firestore
        await _guardarEnFirestore(nuevaMaquina);

        // Backup local opcional
        await _guardarEnStorageLocal(nuevaMaquina);

        // Llamar callback
        widget.onSave(nuevaMaquina);

        setState(() { _cargando = false; });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Máquina guardada exitosamente en Firebase'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        setState(() { _cargando = false; });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en Firebase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarEnFirestore(Map<String, dynamic> nuevaMaquina) async {
    try {
      final maquinasCollection = _firestore.collection('maquinas');

      if (widget.maquinaExistente != null) {
        // Actualizar máquina existente
        final docId = widget.maquinaExistente!['docId'] ?? nuevaMaquina['id'];
        await maquinasCollection.doc(docId).set(nuevaMaquina, SetOptions(merge: true));
        print('Máquina actualizada en Firestore con ID: $docId');
      } else {
        // Crear nueva máquina
        final docRef = await maquinasCollection.add(nuevaMaquina);
        print('Nueva máquina creada en Firestore con ID: ${docRef.id}');

        // Actualizar el documento con su propio ID para referencia futura
        await docRef.update({'docId': docRef.id});
        nuevaMaquina['docId'] = docRef.id;
      }
    } catch (e) {
      print('Error al guardar en Firestore: $e');
      throw e;
    }
  }

  // Método de backup: guardar también localmente (opcional)
  Future<void> _guardarEnStorageLocal(Map<String, dynamic> nuevaMaquina) async {
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
      print('Error al guardar backup local: $e');
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

  Widget _buildEstadoCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Estado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            DropdownButtonFormField<String>(
              value: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado de la máquina',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                DropdownMenuItem(value: 'En Taller', child: Text('En Taller')),
                DropdownMenuItem(value: 'Fuera de Servicio', child: Text('Fuera de Servicio')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() { _estado = value; });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionTecnicaCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Revisión Técnica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(
                  'Fecha: ${_formatearFecha(_fechaRevisionTecnica)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _seleccionarFecha(
                    context,
                    _fechaRevisionTecnica,
                        (fecha) => setState(() => _fechaRevisionTecnica = fecha),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Seleccionar fecha'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool esEdicion) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _guardarMaquina,
        style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 4,
            shadowColor: theme.colorScheme.primary.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        ),
        icon: const Icon(Icons.cloud_upload),
        label: Text(
            esEdicion ? 'Actualizar en Firebase' : 'Guardar en Firebase',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.maquinaExistente != null;
    final titulo = esEdicion ? 'Editar Máquina' : 'Agregar Máquina';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        centerTitle: true,
        elevation: 0,
      ),
      body: _cargando
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Guardando en Firebase...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      )
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.05),
              theme.colorScheme.background
            ],
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
                _buildIdentificacionCard(),
                const SizedBox(height: 20),
                _buildMantenimientoCard(),
                const SizedBox(height: 20),
                _buildComentarioCard(),
                const SizedBox(height: 20),
                _buildImagenCard(),
                const SizedBox(height: 20),
                _buildEstadoCard(),
                const SizedBox(height: 20),
                _buildRevisionTecnicaCard(),
                const SizedBox(height: 40),
                _buildSaveButton(esEdicion),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificacionCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Identificación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Número de Máquina
            TextFormField(
              controller: _numeroMaquinaController,
              decoration: InputDecoration(
                labelText: 'Número de Máquina *',
                prefixIcon: Icon(Icons.tag, color: theme.colorScheme.primary),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El número de máquina es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Patente
            TextFormField(
              controller: _patenteController,
              decoration: InputDecoration(
                labelText: 'Patente * (máx. 8 caracteres)',
                prefixIcon: Icon(Icons.credit_card, color: theme.colorScheme.primary),
                counterText: "",
              ),
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La patente es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Modelo
            TextFormField(
              controller: _modeloController,
              decoration: InputDecoration(
                labelText: 'Modelo *',
                prefixIcon: Icon(Icons.directions_bus, color: theme.colorScheme.primary),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El modelo es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Capacidad y Kilometraje
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacidadController,
                    decoration: InputDecoration(
                      labelText: 'Capacidad de pasajeros',
                      prefixIcon: Icon(Icons.people, color: theme.colorScheme.primary),
                      suffixText: 'pas.',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _kilometrajeController,
                    decoration: InputDecoration(
                      labelText: 'Kilometraje',
                      prefixIcon: Icon(Icons.speed, color: theme.colorScheme.primary),
                      suffixText: 'km',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Número de VIN
            TextFormField(
              controller: _vinController,
              decoration: InputDecoration(
                labelText: 'Número de VIN',
                prefixIcon: Icon(Icons.numbers, color: theme.colorScheme.primary),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMantenimientoCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Mantenimiento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _agregarElementoMantenimiento,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'Agregar elemento',
                ),
              ],
            ),
            const Divider(height: 24),

            // Lista de elementos de mantenimiento
            ..._elementosMantenimiento.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> elemento = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: elemento['tituloController'],
                            decoration: const InputDecoration(
                              labelText: 'Título',
                              isDense: true,
                            ),
                            onChanged: (value) => elemento['titulo'] = value,
                          ),
                        ),
                        if (_elementosMantenimiento.length > 1)
                          IconButton(
                            icon: Icon(Icons.delete, color: theme.colorScheme.error),
                            onPressed: () => _eliminarElementoMantenimiento(index),
                            tooltip: 'Eliminar elemento',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: elemento['descripcionController'],
                      decoration: const InputDecoration(
                        labelText: 'Descripción (modelo, especificaciones, etc.)',
                        isDense: true,
                      ),
                      maxLines: 2,
                      onChanged: (value) => elemento['descripcion'] = value,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: elemento['tieneFecha'] ?? true,
                          onChanged: (value) {
                            setState(() {
                              elemento['tieneFecha'] = value ?? true;
                              if (!elemento['tieneFecha']) {
                                elemento['fecha'] = null;
                              }
                            });
                          },
                        ),
                        const Text('Incluir fecha de revisión'),
                      ],
                    ),
                    if (elemento['tieneFecha'] == true) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Última revisión: ${_formatearFecha(elemento['fecha'])}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => _seleccionarFecha(
                              context,
                              elemento['fecha'],
                                  (fecha) => setState(() => elemento['fecha'] = fecha),
                            ),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: const Text('Cambiar fecha'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComentarioCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Comentario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _comentarioController,
              decoration: const InputDecoration(
                hintText: 'Ingrese comentarios sobre la máquina',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagenCard() {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Imagen de la Máquina',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_imagenMaquina != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_imagenMaquina!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: _verImagen,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver imagen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _seleccionarImagen,
                    icon: const Icon(Icons.edit),
                    label: const Text('Cambiar imagen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _eliminarImagen,
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    label: Text('Eliminar', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
              ),
            ] else ...[
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay imagen seleccionada',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _seleccionarImagen,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Seleccionar imagen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Liberar controladores principales
    _numeroMaquinaController.dispose();
    _patenteController.dispose();
    _modeloController.dispose();
    _capacidadController.dispose();
    _kilometrajeController.dispose();
    _vinController.dispose();
    _comentarioController.dispose();

    // Liberar controladores de mantenimiento
    for (var elemento in _elementosMantenimiento) {
      elemento['tituloController']?.dispose();
      elemento['descripcionController']?.dispose();
    }

    super.dispose();
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
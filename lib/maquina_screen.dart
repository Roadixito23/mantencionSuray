import 'package:flutter/material.dart';
import 'edit_maquina_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class MaquinaScreen extends StatefulWidget {
  const MaquinaScreen({Key? key}) : super(key: key);

  @override
  _MaquinaScreenState createState() => _MaquinaScreenState();
}

class _MaquinaScreenState extends State<MaquinaScreen> {
  // Lista de datos de máquinas (autobuses)
  List<Map<String, dynamic>> _maquinas = [];
  bool _cargando = true;

  // Variable para controlar la máquina seleccionada en la vista horizontal
  int _maquinaSeleccionadaIndex = 0;

  // Controles de visualización
  bool _mostrarFiltros = true;
  bool _mostrarOtrasRevisiones = true;
  bool _mostrarComentarios = true;

  // Colores estándar
  final Color _colorPrimario = Colors.blue;
  final Color _colorAlerta = Colors.red;
  final Color _colorFondo = Colors.white;
  final Color _colorTextoSecundario = Colors.grey.shade600;
  final Color _colorFondoSecundario = Colors.grey.shade50;

  @override
  void initState() {
    super.initState();
    _cargarMaquinas();
  }

  // Cargar máquinas desde el almacenamiento local
  Future<void> _cargarMaquinas() async {
    setState(() {
      _cargando = true;
    });

    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);
        setState(() {
          _maquinas = maquinasJson.cast<Map<String, dynamic>>();
          // Asegurarnos de que el índice seleccionado es válido
          if (_maquinas.isNotEmpty) {
            _maquinaSeleccionadaIndex = 0; // Seleccionar la primera máquina por defecto
          }
          _cargando = false;
        });
      } else {
        setState(() {
          _maquinas = [];
          _cargando = false;
        });
      }
    } catch (e) {
      print('Error al cargar máquinas: $e');
      setState(() {
        _maquinas = [];
        _cargando = false;
      });
    }
  }

  // Método para seleccionar una máquina
  void _seleccionarMaquina(int index) {
    setState(() {
      _maquinaSeleccionadaIndex = index;
    });
  }

  // Obtener el directorio de documentos
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Obtener referencia al archivo
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/maquinas.json');
  }

  // Guardar máquinas en el almacenamiento local
  Future<void> guardarMaquinas(List<Map<String, dynamic>> maquinas) async {
    try {
      final file = await _localFile;
      final jsonString = jsonEncode(maquinas);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error al guardar máquinas: $e');
    }
  }

  // Formatear fecha para mostrar
  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) {
      return 'No registrada';
    }
    try {
      final DateTime fecha = DateTime.parse(fechaIso);
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  // Calcular días restantes para la revisión técnica
  int? _calcularDiasRestantes(String? fechaIso) {
    if (fechaIso == null) {
      return null;
    }
    try {
      final DateTime fechaRevision = DateTime.parse(fechaIso);
      final DateTime ahora = DateTime.now();
      final diferencia = fechaRevision.difference(ahora);
      return diferencia.inDays;
    } catch (e) {
      return null;
    }
  }

  // Método para verificar si una fecha está vencida o próxima a vencer
  EstadoFecha _verificarFecha(String? fechaIso) {
    if (fechaIso == null) {
      return EstadoFecha.normal;
    }

    try {
      final DateTime fechaRevision = DateTime.parse(fechaIso);
      final DateTime ahora = DateTime.now();
      final diferencia = fechaRevision.difference(ahora).inDays;

      if (diferencia < 0) {
        return EstadoFecha.vencida;
      } else if (diferencia <= 30) {
        return EstadoFecha.proxima;
      } else {
        return EstadoFecha.normal;
      }
    } catch (e) {
      return EstadoFecha.normal;
    }
  }

  // Obtener color según estado de fecha
  Color _getColorEstadoFecha(String? fechaIso) {
    final estado = _verificarFecha(fechaIso);

    switch (estado) {
      case EstadoFecha.vencida:
        return _colorAlerta;
      case EstadoFecha.proxima:
        return Colors.orange;
      case EstadoFecha.normal:
        return _colorPrimario;
    }
  }

  // Verificar si hay máquinas con revisión próxima a vencer (1 mes)
  bool get _hayAlertasRevisionTecnica {
    for (var maquina in _maquinas) {
      final dias = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
      if (dias != null && dias >= 0 && dias <= 30) {
        return true;
      }
    }
    return false;
  }

  // Agregar o editar comentario
  Future<void> _agregarComentario(Map<String, dynamic> maquina) async {
    TextEditingController comentarioController = TextEditingController(
        text: maquina['comentario'] ?? ''
    );

    // Lista de fotos actual (si existen)
    List<String> fotos = maquina['fotos'] != null ?
    List<String>.from(maquina['fotos']) : [];

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.6,  // 60% del ancho de la ventana
                height: MediaQuery.of(context).size.height * 0.7, // 70% del alto de la ventana
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, color: _colorPrimario),
                        const SizedBox(width: 8),
                        Text(
                          'Comentarios - ${maquina['placa']} (${maquina['modelo']})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Cerrar',
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),

                    const Text(
                      'Ingrese comentarios sobre la máquina:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Campo de texto para comentarios
                    TextField(
                      controller: comentarioController,
                      decoration: const InputDecoration(
                        hintText: 'Escriba sus comentarios aquí',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),

                    const SizedBox(height: 20),

                    // Sección de fotos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Fotos adjuntas:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final nuevasFotos = await _seleccionarFotos();
                            if (nuevasFotos.isNotEmpty) {
                              setState(() {
                                fotos.addAll(nuevasFotos);
                              });
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Agregar fotos'),
                          style: TextButton.styleFrom(foregroundColor: _colorPrimario),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Lista de fotos (con scroll)
                    Expanded(
                      child: fotos.isEmpty
                          ? Center(
                        child: Text(
                          'No hay fotos adjuntas',
                          style: TextStyle(
                            color: _colorTextoSecundario,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                          : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: fotos.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              InkWell(
                                onTap: () => _verFoto(fotos[index]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(fotos[index]),
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

                              // Botón para eliminar foto
                              Positioned(
                                top: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      fotos.removeAt(index);
                                    });
                                  },
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
                    ),

                    const SizedBox(height: 16),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _colorTextoSecundario,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Actualizar el comentario y las fotos
                            final index = _maquinas.indexWhere((m) => m['id'] == maquina['id']);
                            if (index != -1) {
                              this.setState(() {
                                _maquinas[index]['comentario'] = comentarioController.text;
                                _maquinas[index]['fotos'] = fotos;
                                // Añadir fecha de modificación
                                _maquinas[index]['fechaModificacion'] = DateTime.now().toIso8601String();
                              });
                              guardarMaquinas(_maquinas);
                            }
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Comentario guardado con éxito'),
                                backgroundColor: _colorPrimario,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _colorPrimario,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
        ),
      ),
    );
  }

  // Método para seleccionar y agregar fotos
  Future<List<String>> _seleccionarFotos() async {
    List<String> nuevasFotos = [];
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
            nuevasFotos.add(targetPath);
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
    return nuevasFotos;
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
            foregroundColor: Colors.white,
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

  bool get _hayDatos => _maquinas.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isHorizontal = mediaQuery.size.width > mediaQuery.size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Máquinas'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _colorPrimario,
        foregroundColor: Colors.white,
        actions: [
          // Menú de modelos de filtros y revisiones
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Modelos de filtros y revisiones',
            onPressed: () {
              _mostrarDialogoModelos();
            },
          ),
          // Botón de opciones de visualización
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility),
            tooltip: 'Opciones de visualización',
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'filtros':
                    _mostrarFiltros = !_mostrarFiltros;
                    break;
                  case 'revisiones':
                    _mostrarOtrasRevisiones = !_mostrarOtrasRevisiones;
                    break;
                  case 'comentarios':
                    _mostrarComentarios = !_mostrarComentarios;
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'filtros',
                checked: _mostrarFiltros,
                child: const Text('Mostrar Filtros'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'revisiones',
                checked: _mostrarOtrasRevisiones,
                child: const Text('Mostrar Otras Revisiones'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'comentarios',
                checked: _mostrarComentarios,
                child: const Text('Mostrar Comentarios'),
              ),
            ],
          ),
        ],
        bottom: _hayAlertasRevisionTecnica ? PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.all(10),
            color: _colorAlerta.withOpacity(0.1),
            width: double.infinity,
            child: Row(
              children: [
                Icon(Icons.warning, color: _colorAlerta),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Tienes máquinas con revisión técnica próxima a vencer!',
                    style: TextStyle(
                      color: _colorAlerta,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ) : null,
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: _colorPrimario))
          : (_hayDatos
          ? _construirListaDatos(isHorizontal)
          : _construirMensajeVacio()),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditMaquinaScreen(
                onSave: (nuevaMaquina) {
                  setState(() {
                    // Si ya existe la máquina, actualizarla
                    int index = _maquinas.indexWhere((m) => m['id'] == nuevaMaquina['id']);
                    if (index >= 0) {
                      _maquinas[index] = nuevaMaquina;
                    } else {
                      // Si no existe, agregarla
                      _maquinas.add(nuevaMaquina);
                    }
                  });
                  guardarMaquinas(_maquinas);
                },
              ),
            ),
          ).then((_) => _cargarMaquinas());
        },
        backgroundColor: _colorPrimario,
        child: const Icon(Icons.add),
        tooltip: 'Agregar Nueva Máquina',
      ),
    );
  }

  void _mostrarDialogoModelos() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, color: _colorPrimario),
                  const SizedBox(width: 8),
                  const Text(
                    'Modelos de Filtros y Revisiones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _maquinas.map((maquina) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          title: Text('${maquina['placa']} - ${maquina['modelo']}'),
                          leading: const Icon(Icons.directions_bus),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            _construirInfoModelo('Filtro Aceite:', maquina['modeloFiltroAceite']),
                            _construirInfoModelo('Filtro Aire:', maquina['modeloFiltroAire']),
                            _construirInfoModelo('Filtro Petróleo:', maquina['modeloFiltroPetroleo']),
                            _construirInfoModelo('Decantador:', maquina['modeloDecantador']),
                            if (maquina['correas'] != null && (maquina['correas'] as List).isNotEmpty)
                              _construirInfoModelo('Correa:', (maquina['correas'] as List).first['modelo']),
                            if (maquina['modeloCorrea'] != null)
                              _construirInfoModelo('Correa:', maquina['modeloCorrea']),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorPrimario,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirInfoModelo(String titulo, String? modelo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(modelo ?? 'No especificado'),
        ],
      ),
    );
  }

  // Método para obtener texto corto para modelo (evitar desbordamiento)
  String _getModeloCorto(String? modelo) {
    if (modelo == null || modelo.isEmpty) {
      return 'N/E';
    }
    return modelo.length > 10 ? '${modelo.substring(0, 8)}...' : modelo;
  }

  Widget _construirListaDatos(bool isHorizontal) {
    if (isHorizontal) {
      // Diseño optimizado para modo horizontal (Windows)
      return _construirListaDatosHorizontal();
    } else {
      // Diseño original para modo vertical (móvil) con mejoras
      return _construirListaDatosVertical();
    }
  }

  // Vista optimizada para Windows (horizontal)
  Widget _construirListaDatosHorizontal() {
    return Row(
        children: [
    // Panel lateral con lista de máquinas (30% del ancho)
    Container(
    width: MediaQuery.of(context).size.width * 0.3,
    decoration: BoxDecoration(
    color: _colorFondoSecundario,
    border: Border(
    right: BorderSide(color: Colors.grey.shade300),
    ),
    ),
    child: Column(
    children: [
    // Barra de búsqueda
    Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextField(
    decoration: InputDecoration(
    hintText: 'Buscar máquina...',
    prefixIcon: const Icon(Icons.search),
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 0),
    ),
    // Implementar lógica de búsqueda si se requiere
    ),
    ),
      // Lista de máquinas
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargarMaquinas,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _maquinas.length,
            itemBuilder: (context, index) {
              final maquina = _maquinas[index];
              final diasRestantes = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
              final estadoFecha = _verificarFecha(maquina['fechaRevisionTecnica']);
              final bool hayAlerta = estadoFecha != EstadoFecha.normal;
              final Color colorAlerta = estadoFecha == EstadoFecha.vencida ? _colorAlerta : Colors.orange;
              final bool estaSeleccionada = index == _maquinaSeleccionadaIndex;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: estaSeleccionada
                        ? _colorPrimario
                        : (hayAlerta ? colorAlerta : Colors.transparent),
                    width: estaSeleccionada || hayAlerta ? 1.5 : 0,
                  ),
                ),
                color: estaSeleccionada ? _colorPrimario.withOpacity(0.05) : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hayAlerta
                          ? colorAlerta.withOpacity(0.1)
                          : (maquina['estado'] == 'Activo'
                          ? _colorPrimario.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: hayAlerta
                          ? colorAlerta
                          : (maquina['estado'] == 'Activo'
                          ? _colorPrimario
                          : Colors.orange),
                      size: 28,
                    ),
                  ),
                  title: Text(
                    maquina['placa'] ?? 'Sin placa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: estaSeleccionada
                          ? _colorPrimario
                          : (hayAlerta ? colorAlerta : null),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maquina['modelo'] ?? 'Sin modelo',
                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: hayAlerta ? colorAlerta : _colorPrimario
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatearFecha(maquina['fechaRevisionTecnica']),
                            style: TextStyle(
                              color: hayAlerta ? colorAlerta : null,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: maquina['estado'] == 'Activo'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: maquina['estado'] == 'Activo'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    child: Text(
                      maquina['estado'] ?? 'Sin estado',
                      style: TextStyle(
                        color: maquina['estado'] == 'Activo'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Seleccionar esta máquina
                    _seleccionarMaquina(index);
                  },
                ),
              );
            },
          ),
        ),
      ),
    ],
    ),
    ),

          // Panel de detalle de la máquina seleccionada (70% del ancho)
          Expanded(
            child: _maquinas.isEmpty
                ? Center(
              child: Text(
                'Seleccione una máquina para ver detalles',
                style: TextStyle(color: _colorTextoSecundario),
              ),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _construirDetalleMaquina(_maquinas[_maquinaSeleccionadaIndex]),  // Mostrar la máquina seleccionada
            ),
          ),
        ],
    );
  }

  // Widget para mostrar el detalle de una máquina en el panel derecho
  Widget _construirDetalleMaquina(Map<String, dynamic> maquina) {
    final diasRestantes = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
    final estadoFecha = _verificarFecha(maquina['fechaRevisionTecnica']);
    final bool hayAlerta = estadoFecha != EstadoFecha.normal;
    final Color colorAlerta = estadoFecha == EstadoFecha.vencida ? _colorAlerta : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado con información principal
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono y estado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hayAlerta
                    ? colorAlerta.withOpacity(0.1)
                    : (maquina['estado'] == 'Activo'
                    ? _colorPrimario.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_bus,
                size: 48,
                color: hayAlerta
                    ? colorAlerta
                    : (maquina['estado'] == 'Activo' ? _colorPrimario : Colors.orange),
              ),
            ),

            const SizedBox(width: 20),

            // Información principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        maquina['placa'] ?? 'Sin placa',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: hayAlerta ? colorAlerta : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: maquina['estado'] == 'Activo'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: maquina['estado'] == 'Activo'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        child: Text(
                          maquina['estado'] ?? 'Sin estado',
                          style: TextStyle(
                            color: maquina['estado'] == 'Activo'
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Modelo: ${maquina['modelo'] ?? 'No especificado'}',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${maquina['id'] ?? 'No especificado'}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _infoItem(
                        Icons.people,
                        'Capacidad',
                        '${maquina['capacidad'] ?? 0} pasajeros',
                      ),
                      const SizedBox(width: 24),
                      _infoItem(
                        Icons.speed,
                        'Kilometraje',
                        '${maquina['kilometraje'] ?? 0} km',
                      ),
                      if (maquina['bin'] != null && maquina['bin'].toString().isNotEmpty) ...[
                        const SizedBox(width: 24),
                        _infoItem(
                          Icons.numbers,
                          'Número BIN',
                          maquina['bin'] ?? '',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Botones de acción
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar máquina',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditMaquinaScreen(
                          maquinaExistente: maquina,
                          onSave: (maquinaActualizada) {
                            setState(() {
                              final index = _maquinas.indexWhere(
                                      (m) => m['id'] == maquinaActualizada['id']
                              );
                              if (index != -1) {
                                _maquinas[index] = maquinaActualizada;
                              }
                            });
                            guardarMaquinas(_maquinas);
                          },
                        ),
                      ),
                    ).then((_) => _cargarMaquinas());
                  },
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar máquina',
                  color: _colorAlerta,
                  onPressed: () {
                    _mostrarDialogoEliminar(maquina);
                  },
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Tarjeta de revisión técnica
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: hayAlerta ? colorAlerta : Colors.grey.shade300,
              width: hayAlerta ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.safety_check,
                      color: hayAlerta ? colorAlerta : _colorPrimario,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Revisión Técnica',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hayAlerta ? colorAlerta : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fecha de última revisión:',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatearFecha(maquina['fechaRevisionTecnica']),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hayAlerta ? colorAlerta : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (diasRestantes != null)
                      _buildDiasRestantes(diasRestantes),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Secciones condicionales (filtros, revisiones, etc.)
        if (_mostrarFiltros)
          _construirSeccionFiltros(maquina),

        if (_mostrarOtrasRevisiones)
          _construirSeccionOtrasRevisiones(maquina),

        if (_mostrarComentarios)
          _construirSeccionComentarios(maquina),
      ],
    );
  }

  // Obtener texto de alerta para mostrar días restantes
  Widget _buildDiasRestantes(int? dias) {
    if (dias == null) {
      return Text(
        'Sin fecha programada',
        style: TextStyle(
          color: _colorTextoSecundario,
          fontSize: 12,
        ),
      );
    }

    final bool esVencido = dias < 0;
    final String textoMostrar = esVencido
        ? 'Vencido hace ${-dias} días'
        : 'Faltan $dias días';
    final Color colorTexto = dias < 0
        ? _colorAlerta
        : (dias <= 30 ? Colors.orange : Colors.green);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorTexto.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorTexto),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esVencido ? Icons.warning : Icons.access_time,
            size: 16,
            color: colorTexto,
          ),
          const SizedBox(width: 4),
          Text(
            textoMostrar,
            style: TextStyle(
              color: colorTexto,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Sección de filtros para vista horizontal
  Widget _construirSeccionFiltros(Map<String, dynamic> maquina) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt, color: _colorPrimario),
            const SizedBox(width: 8),
            const Text(
              'Mantenimiento de Filtros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid de filtros
        Row(
          children: [
            Expanded(
              child: _tarjetaFiltro(
                'Filtro de Aceite',
                maquina['modeloFiltroAceite'] ?? 'No especificado',
                _formatearFecha(maquina['fechaCambioFiltroAceite']),
                Icons.oil_barrel,
                _getColorEstadoFecha(maquina['fechaCambioFiltroAceite']),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _tarjetaFiltro(
                'Filtro de Aire',
                maquina['modeloFiltroAire'] ?? 'No especificado',
                _formatearFecha(maquina['fechaCambioFiltroAire']),
                Icons.air,
                _getColorEstadoFecha(maquina['fechaCambioFiltroAire']),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _tarjetaFiltro(
                'Filtro de Petróleo',
                maquina['modeloFiltroPetroleo'] ?? 'No especificado',
                _formatearFecha(maquina['fechaCambioFiltroPetroleo']),
                Icons.local_gas_station,
                _getColorEstadoFecha(maquina['fechaCambioFiltroPetroleo']),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  // Widget para tarjeta de filtro
  Widget _tarjetaFiltro(String titulo, String modelo, String fecha, IconData icono, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color == _colorPrimario ? Colors.grey.shade300 : color.withOpacity(0.5),
          width: color == _colorPrimario ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Modelo: ',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: Text(
                    modelo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Último cambio: ',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                Text(
                  fecha,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color == _colorPrimario ? null : color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Sección de otras revisiones para vista horizontal
  Widget _construirSeccionOtrasRevisiones(Map<String, dynamic> maquina) {
    // Obtener las correas (nueva estructura o antigua)
    List<Map<String, dynamic>> correas = [];
    if (maquina['correas'] != null && maquina['correas'] is List) {
      correas = List<Map<String, dynamic>>.from(maquina['correas']);
    } else if (maquina['modeloCorrea'] != null) {
      correas = [{
        'modelo': maquina['modeloCorrea'],
        'fecha': maquina['fechaRevisionCorrea'],
      }];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build, color: _colorPrimario),
            const SizedBox(width: 8),
            const Text(
              'Otras Revisiones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid de revisiones
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _tarjetaFiltro(
                'Decantador',
                maquina['modeloDecantador'] ?? 'No especificado',
                _formatearFecha(maquina['fechaRevisionDecantador']),
                Icons.water_drop,
                _getColorEstadoFecha(maquina['fechaRevisionDecantador']),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              // Mostrar primera correa en la vista principal
              child: correas.isNotEmpty
                  ? _tarjetaFiltro(
                'Correa Principal',
                correas.first['modelo'] ?? 'No especificado',
                _formatearFecha(correas.first['fecha']),
                Icons.settings_input_component,
                _getColorEstadoFecha(correas.first['fecha']),
              )
                  : _tarjetaFiltro(
                'Correa',
                'No especificado',
                'No registrada',
                Icons.settings_input_component,
                _colorPrimario,
              ),
            ),
            const SizedBox(width: 16),
            // Espacio para mantener la simetría en el diseño
            Expanded(child: Container()),
          ],
        ),

        // Mostrar el resto de correas si hay más de una
        if (correas.length > 1) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Correas adicionales:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: correas.length - 1, // Excluir la primera que ya se mostró
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, i) {
                      final index = i + 1; // Comenzar desde la segunda correa
                      final correa = correas[index];
                      final color = _getColorEstadoFecha(correa['fecha']);

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.settings_input_component, size: 20, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Correa ${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  'Modelo: ${correa['modelo'] ?? 'No especificado'}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Última revisión:',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                _formatearFecha(correa['fecha']),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color == _colorPrimario ? null : color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  // Sección de comentarios para vista horizontal
  Widget _construirSeccionComentarios(Map<String, dynamic> maquina) {
    // Extraer fotos y comentarios
    final List<String> fotos = maquina['fotos'] != null ?
    List<String>.from(maquina['fotos']) : [];
    final String comentario = maquina['comentario'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.comment, color: _colorPrimario),
                const SizedBox(width: 8),
                const Text(
                  'Comentarios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _agregarComentario(maquina),
              icon: const Icon(Icons.edit),
              label: const Text('Editar comentarios'),
              style: TextButton.styleFrom(
                foregroundColor: _colorPrimario,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mostrar comentario si existe
        if (comentario.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colorFondoSecundario,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              comentario,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colorFondoSecundario,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No hay comentarios para esta máquina.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: _colorTextoSecundario,
              ),
            ),
          ),
        ],

        // Mostrar fotos si existen
        if (fotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Fotos adjuntas:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // Grid de fotos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => _verFoto(fotos[index]),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(fotos[index]),
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
              );
            },
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  // Widget para información en el panel de detalle
  Widget _infoItem(IconData icon, String titulo, String valor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _colorPrimario),
        const SizedBox(width: 6),
        Text(
          '$titulo: ',
          style: TextStyle(
            color: _colorTextoSecundario,
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Diálogo para eliminar máquina
  void _mostrarDialogoEliminar(Map<String, dynamic> maquina) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Eliminar Máquina'),
            content: Text('¿Estás seguro de que deseas eliminar la máquina ${maquina['placa']}?'),
            actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
    child: const Text('Cancelar'),
    ),
    ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: _colorAlerta),
    onPressed: () async {
    // Guardar el índice antes de eliminar
    int indexEliminado = _maquinas.indexWhere((m) => m['id'] == maquina['id']);

    setState(() {
    _maquinas.remove(maquina);

// Actualizar el índice seleccionado después de eliminar
      if (_maquinas.isNotEmpty) {
        if (indexEliminado < _maquinaSeleccionadaIndex) {
          // Si se eliminó una máquina antes de la seleccionada, ajustar el índice
          _maquinaSeleccionadaIndex = _maquinaSeleccionadaIndex - 1;
        } else if (indexEliminado == _maquinaSeleccionadaIndex) {
          // Si se eliminó la máquina seleccionada, seleccionar otra
          _maquinaSeleccionadaIndex = _maquinaSeleccionadaIndex >= _maquinas.length
              ? _maquinas.length - 1
              : _maquinaSeleccionadaIndex;
        }
        // Si se eliminó una después de la seleccionada, el índice sigue siendo válido
      }
    });

    await guardarMaquinas(_maquinas);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Máquina eliminada con éxito'),
        backgroundColor: _colorAlerta,
      ),
    );
    },
      child: const Text(
        'Eliminar',
        style: TextStyle(color: Colors.white),
      ),
    ),
            ],
        ),
    );
  }

  // Vista original para móvil (vertical) con mejoras
  Widget _construirListaDatosVertical() {
    return RefreshIndicator(
      onRefresh: _cargarMaquinas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _maquinas.length,
        itemBuilder: (context, index) {
          final maquina = _maquinas[index];
          return _construirTarjetaMaquina(maquina, index);
        },
      ),
    );
  }

  // Función modificada para construir tarjeta de máquina en vista vertical
  Widget _construirTarjetaMaquina(Map<String, dynamic> maquina, int index) {
    final diasRestantes = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
    final estadoFecha = _verificarFecha(maquina['fechaRevisionTecnica']);
    final bool hayAlerta = estadoFecha != EstadoFecha.normal;
    final bool tieneComentarios = maquina['comentario'] != null &&
        maquina['comentario'].toString().isNotEmpty;
    final List<String> fotos = maquina['fotos'] != null ?
    List<String>.from(maquina['fotos']) : [];
    final Color colorAlerta = estadoFecha == EstadoFecha.vencida ? _colorAlerta : Colors.orange;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hayAlerta ? colorAlerta : Colors.transparent,
          width: hayAlerta ? 1.5 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de la tarjeta
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hayAlerta ? colorAlerta.withOpacity(0.1) : _colorPrimario.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primera fila: ID, placa, modelo, estado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hayAlerta ? colorAlerta.withOpacity(0.2) : _colorPrimario.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_bus,
                        size: 28,
                        color: hayAlerta ? colorAlerta : _colorPrimario,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Placa y modelo con estilo mejorado
                          Text(
                            maquina['placa'] ?? 'Sin placa',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: hayAlerta ? colorAlerta : Colors.black87,
                            ),
                          ),
                          Text(
                            maquina['modelo'] ?? 'Sin modelo',
                            style: TextStyle(
                              fontSize: 16,
                              color: _colorTextoSecundario,
                            ),
                          ),
                          Text(
                            'ID: ${maquina['id']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _colorTextoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: maquina['estado'] == 'Activo'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: maquina['estado'] == 'Activo'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        maquina['estado'] ?? 'Sin estado',
                        style: TextStyle(
                          color: maquina['estado'] == 'Activo'
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                // Información de revisión técnica con días restantes
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: hayAlerta ? colorAlerta.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: hayAlerta ? colorAlerta.withOpacity(0.5) : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.safety_check,
                            size: 18,
                            color: hayAlerta ? colorAlerta : _colorPrimario,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Revisión Técnica',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: hayAlerta ? colorAlerta : _colorPrimario,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatearFecha(maquina['fechaRevisionTecnica']),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hayAlerta ? FontWeight.bold : FontWeight.normal,
                              color: hayAlerta ? colorAlerta : Colors.black87,
                            ),
                          ),
                          if (diasRestantes != null)
                            _buildDiasRestantes(diasRestantes),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Información general de pasajeros y km
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _infoItemVerticalMejorado(
                  Icons.people,
                  'Capacidad',
                  '${maquina['capacidad'] ?? 0} pasajeros',
                ),
                const SizedBox(width: 24),
                _infoItemVerticalMejorado(
                  Icons.speed,
                  'Kilometraje',
                  '${maquina['kilometraje'] ?? 0} km',
                ),
                if (maquina['bin'] != null && maquina['bin'].toString().isNotEmpty) ...[
                  const SizedBox(width: 24),
                  _infoItemVerticalMejorado(
                    Icons.numbers,
                    'Número BIN',
                    maquina['bin'] ?? '',
                  ),
                ],
              ],
            ),
          ),

          // Panel expandible para detalles
          ExpansionTile(
            title: const Text(
              'Ver detalles y filtros',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: Icon(Icons.view_list, color: _colorPrimario),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            childrenPadding: const EdgeInsets.all(16),
            children: [
              // Secciones condicionales (filtros, revisiones, etc.)
              if (_mostrarFiltros) ...[
                _buildSeccionFiltrosMejorada(maquina),
                const SizedBox(height: 16),
              ],

              if (_mostrarOtrasRevisiones) ...[
                _buildSeccionOtrasRevisionesMejorada(maquina),
                const SizedBox(height: 16),
              ],

              if (tieneComentarios || fotos.isNotEmpty) ...[
                _buildSeccionComentariosMejorada(maquina, tieneComentarios, fotos),
              ],
            ],
          ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _agregarComentario(maquina),
                  icon: const Icon(Icons.comment),
                  label: const Text('Comentario'),
                  style: TextButton.styleFrom(foregroundColor: _colorPrimario),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditMaquinaScreen(
                          maquinaExistente: maquina,
                          onSave: (maquinaActualizada) {
                            setState(() {
                              final index = _maquinas.indexWhere(
                                      (m) => m['id'] == maquinaActualizada['id']
                              );
                              if (index != -1) {
                                _maquinas[index] = maquinaActualizada;
                              }
                            });
                            guardarMaquinas(_maquinas);
                          },
                        ),
                      ),
                    ).then((_) => _cargarMaquinas());
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  style: TextButton.styleFrom(foregroundColor: _colorPrimario),
                ),
                TextButton.icon(
                  onPressed: () {
                    _mostrarDialogoEliminar(maquina);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar'),
                  style: TextButton.styleFrom(foregroundColor: _colorAlerta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar un elemento de información (versión vertical mejorada)
  Widget _infoItemVerticalMejorado(IconData icon, String titulo, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colorPrimario.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: _colorPrimario),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: _colorTextoSecundario,
                    ),
                  ),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sección de filtros mejorada para vista vertical
  Widget _buildSeccionFiltrosMejorada(Map<String, dynamic> maquina) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt, color: _colorPrimario),
            const SizedBox(width: 8),
            Text(
              'Filtros',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _colorPrimario,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildFilaFiltroMejorada(
                'Filtro de Aceite',
                maquina['modeloFiltroAceite'] ?? 'No especificado',
                maquina['fechaCambioFiltroAceite'],
                Icons.oil_barrel,
              ),
              const Divider(height: 1),
              _buildFilaFiltroMejorada(
                'Filtro de Aire',
                maquina['modeloFiltroAire'] ?? 'No especificado',
                maquina['fechaCambioFiltroAire'],
                Icons.air,
              ),
              const Divider(height: 1),
              _buildFilaFiltroMejorada(
                'Filtro de Petróleo',
                maquina['modeloFiltroPetroleo'] ?? 'No especificado',
                maquina['fechaCambioFiltroPetroleo'],
                Icons.local_gas_station,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Fila de filtro mejorada para vista vertical
  Widget _buildFilaFiltroMejorada(String titulo, String modelo, String? fechaIso, IconData icono) {
    final estadoFecha = _verificarFecha(fechaIso);
    final color = estadoFecha == EstadoFecha.vencida
        ? _colorAlerta
        : (estadoFecha == EstadoFecha.proxima ? Colors.orange : _colorPrimario);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'Modelo: $modelo',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Último cambio:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                _formatearFecha(fechaIso),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: estadoFecha != EstadoFecha.normal ? color : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sección de otras revisiones mejorada para vista vertical
  Widget _buildSeccionOtrasRevisionesMejorada(Map<String, dynamic> maquina) {
    // Obtener las correas (nueva estructura o antigua)
    List<Map<String, dynamic>> correas = [];
    if (maquina['correas'] != null && maquina['correas'] is List) {
      correas = List<Map<String, dynamic>>.from(maquina['correas']);
    } else if (maquina['modeloCorrea'] != null) {
      correas = [{
        'modelo': maquina['modeloCorrea'],
        'fecha': maquina['fechaRevisionCorrea'],
      }];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build, color: _colorPrimario),
            const SizedBox(width: 8),
            Text(
              'Otras Revisiones',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _colorPrimario,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildFilaFiltroMejorada(
                'Decantador',
                maquina['modeloDecantador'] ?? 'No especificado',
                maquina['fechaRevisionDecantador'],
                Icons.water_drop,
              ),
              if (correas.isNotEmpty) ...[
                const Divider(height: 1),
                _buildFilaFiltroMejorada(
                  'Correa Principal',
                  correas.first['modelo'] ?? 'No especificado',
                  correas.first['fecha'],
                  Icons.settings_input_component,
                ),
              ],
            ],
          ),
        ),

        // Mostrar correas adicionales si hay más de una
        if (correas.length > 1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correas adicionales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _colorPrimario,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: correas.length - 1,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final index = i + 1;
                    final correa = correas[index];
                    final estadoFecha = _verificarFecha(correa['fecha']);
                    final color = estadoFecha == EstadoFecha.vencida
                        ? _colorAlerta
                        : (estadoFecha == EstadoFecha.proxima ? Colors.orange : _colorPrimario);

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.settings_input_component, color: color, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Correa ${index + 1}: ${correa['modelo'] ?? 'No especificado'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: estadoFecha != EstadoFecha.normal ? color : null,
                            ),
                          ),
                        ),
                        Text(
                          _formatearFecha(correa['fecha']),
                          style: TextStyle(
                            fontSize: 12,
                            color: estadoFecha != EstadoFecha.normal ? color : _colorTextoSecundario,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Sección de comentarios mejorada para vista vertical
  Widget _buildSeccionComentariosMejorada(Map<String, dynamic> maquina, bool tieneComentarios, List<String> fotos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.comment, color: _colorPrimario),
            const SizedBox(width: 8),
            Text(
              'Comentarios y Fotos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _colorPrimario,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mostrar comentarios
        if (tieneComentarios) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              maquina['comentario'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No hay comentarios para esta máquina.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: _colorTextoSecundario,
              ),
            ),
          ),
        ],

        // Mostrar fotos si existen
        if (fotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Fotos adjuntas:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _verFoto(fotos[index]),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(fotos[index]),
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
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _construirMensajeVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay máquinas registradas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _colorTextoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Utiliza el botón + para agregar una nueva máquina',
            style: TextStyle(
              fontSize: 16,
              color: _colorTextoSecundario,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Enum para los estados de las fechas
enum EstadoFecha {
  normal,
  proxima,
  vencida
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'edit_maquina_screen.dart';
import 'components/machine_card.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'providers/theme_provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class MaquinaScreen extends StatefulWidget {
  const MaquinaScreen({Key? key}) : super(key: key);

  @override
  _MaquinaScreenState createState() => _MaquinaScreenState();
}

class _MaquinaScreenState extends State<MaquinaScreen> {
  // Lista de datos de máquinas (autobuses)
  List<Map<String, dynamic>> _maquinas = [];
  List<Map<String, dynamic>> _maquinasFiltradas = [];
  bool _cargando = true;
  String _textoFiltro = '';

  // Variable para controlar la máquina seleccionada en la vista horizontal
  int _maquinaSeleccionadaIndex = 0;

  // Controles de visualización
  bool _mostrarFiltros = true;
  bool _mostrarOtrasRevisiones = true;
  bool _mostrarComentarios = true;
  bool _mostrarSoloVencidos = false;
  bool _mostrarSoloProximos = false;
  bool _mostrarPanelFiltros = false;

  @override
  void initState() {
    super.initState();
    _cargarMaquinas();
  }

  // Cargar máquinas desde el almacenamiento local
  Future<void> _cargarMaquinas() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
    });

    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);

        if (mounted) {
          setState(() {
            _maquinas = maquinasJson.cast<Map<String, dynamic>>();
            _maquinaSeleccionadaIndex = 0; // Resetear el índice
            _aplicarFiltros();
            _cargando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _maquinas = [];
            _maquinasFiltradas = [];
            _maquinaSeleccionadaIndex = 0;
            _cargando = false;
          });
        }
      }
    } catch (e) {
      print('Error al cargar máquinas: $e');
      if (mounted) {
        setState(() {
          _maquinas = [];
          _maquinasFiltradas = [];
          _maquinaSeleccionadaIndex = 0;
          _cargando = false;
        });
      }
    }
  }

  // Aplicar filtros de búsqueda y estado
  void _aplicarFiltros() {
    if (!mounted) return;

    List<Map<String, dynamic>> resultado = List.from(_maquinas);

    // Filtrar por texto
    if (_textoFiltro.isNotEmpty) {
      resultado = resultado.where((maquina) {
        final patente = (maquina['patente'] ?? '').toString().toLowerCase();
        final modelo = (maquina['modelo'] ?? '').toString().toLowerCase();
        final id = (maquina['id'] ?? '').toString().toLowerCase();
        final busqueda = _textoFiltro.toLowerCase();

        return patente.contains(busqueda) ||
            modelo.contains(busqueda) ||
            id.contains(busqueda);
      }).toList();
    }

    // Filtrar por vencidos o próximos
    if (_mostrarSoloVencidos) {
      resultado = resultado.where((maquina) {
        final dias = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
        return dias != null && dias < 0; // Vencidos
      }).toList();
    } else if (_mostrarSoloProximos) {
      resultado = resultado.where((maquina) {
        final dias = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
        return dias != null && dias >= 0 && dias <= 30; // Próximos (30 días)
      }).toList();
    }

    if (mounted) {
      setState(() {
        _maquinasFiltradas = resultado;
        // Resetear el índice si no hay elementos o si está fuera de rango
        if (_maquinasFiltradas.isEmpty) {
          _maquinaSeleccionadaIndex = 0;
        } else if (_maquinaSeleccionadaIndex >= _maquinasFiltradas.length) {
          _maquinaSeleccionadaIndex = 0;
        }
        // Asegurar que el índice sea válido
        _maquinaSeleccionadaIndex = _maquinaSeleccionadaIndex.clamp(0,
            _maquinasFiltradas.isEmpty ? 0 : _maquinasFiltradas.length - 1);
      });
    }
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

  // Agregar o editar comentario
  Future<void> _agregarComentario(Map<String, dynamic> maquina) async {
    if (!mounted) return;

    final theme = Theme.of(context);
    TextEditingController comentarioController = TextEditingController(
        text: maquina['comentario'] ?? ''
    );

    // Lista de fotos actual (si existen)
    List<String> fotos = maquina['fotos'] != null ?
    List<String>.from(maquina['fotos']) : [];

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comentarios',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${maquina['patente']} - ${maquina['modelo']}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Cerrar',
                        ),
                      ],
                    ),
                    Divider(color: theme.dividerColor),
                    const SizedBox(height: 16),

                    Text(
                      'Ingrese comentarios sobre la máquina:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Campo de texto para comentarios
                    TextField(
                      controller: comentarioController,
                      decoration: InputDecoration(
                        hintText: 'Escriba sus comentarios aquí',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      maxLines: 5,
                      style: theme.textTheme.bodyLarge,
                    ),

                    const SizedBox(height: 24),

                    // Sección de fotos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fotos adjuntas:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final nuevasFotos = await _seleccionarFotos();
                            if (nuevasFotos.isNotEmpty) {
                              setDialogState(() {
                                fotos.addAll(nuevasFotos);
                              });
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Agregar fotos'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Lista de fotos (con scroll)
                    Expanded(
                      child: fotos.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay fotos adjuntas',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final nuevasFotos = await _seleccionarFotos();
                                if (nuevasFotos.isNotEmpty) {
                                  setDialogState(() {
                                    fotos.addAll(nuevasFotos);
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_a_photo),
                              label: const Text('Agregar fotos'),
                            ),
                          ],
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
                                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(fotos[index]),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: theme.colorScheme.surfaceVariant,
                                          child: Icon(
                                            Icons.broken_image,
                                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),

                              // Botón para eliminar foto
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        fotos.removeAt(index);
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Actualizar el comentario y las fotos
                            final index = _maquinas.indexWhere((m) => m['id'] == maquina['id']);
                            if (index != -1 && mounted) {
                              setState(() {
                                _maquinas[index]['comentario'] = comentarioController.text;
                                _maquinas[index]['fotos'] = fotos;
                                // Añadir fecha de modificación
                                _maquinas[index]['fechaModificacion'] = DateTime.now().toIso8601String();
                              });
                              guardarMaquinas(_maquinas);
                              _aplicarFiltros();
                            }
                            Navigator.pop(context);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Comentario guardado con éxito'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    List<String> nuevasFotos = [];

    try {
      final result = await FilePicker.platform.pickFiles(
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} fotos agregadas'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      print('Error al seleccionar fotos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar fotos: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }

    return nuevasFotos;
  }

  // Ver una foto en pantalla completa
  void _verFoto(String fotoPath) {
    final theme = Theme.of(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Visualizar Foto'),
            backgroundColor: theme.colorScheme.primary,
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
                      Icon(
                          Icons.broken_image,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.6)
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo cargar la imagen',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
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

  void _mostrarDialogoModelos() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Modelos de Filtros y Revisiones',
                    style: theme.textTheme.headlineMedium?.copyWith(
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
              Divider(color: theme.dividerColor),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _maquinas.map((maquina) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: Icon(
                            Icons.directions_bus,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            '${maquina['patente']} - ${maquina['modelo']}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModeloInfoRow('Filtro Aceite:', maquina['modeloFiltroAceite']),
                            const Divider(height: 16),
                            _buildModeloInfoRow('Filtro Aire:', maquina['modeloFiltroAire']),
                            const Divider(height: 16),
                            _buildModeloInfoRow('Filtro Petróleo:', maquina['modeloFiltroPetroleo']),
                            const Divider(height: 16),
                            _buildModeloInfoRow('Decantador:', maquina['modeloDecantador']),

                            // Mostrar correas
                            if (maquina['correas'] != null && (maquina['correas'] as List).isNotEmpty) ...[
                              const Divider(height: 16),
                              _buildModeloInfoRow(
                                  'Correa Principal:',
                                  (maquina['correas'] as List).first['modelo']
                              ),
                              // Mostrar correas adicionales
                              if ((maquina['correas'] as List).length > 1) ...[
                                for (int i = 1; i < (maquina['correas'] as List).length; i++) ...[
                                  const Divider(height: 16),
                                  _buildModeloInfoRow(
                                      'Correa ${i+1}:',
                                      (maquina['correas'] as List)[i]['modelo']
                                  ),
                                ]
                              ]
                            ] else if (maquina['modeloCorrea'] != null) ...[
                              const Divider(height: 16),
                              _buildModeloInfoRow('Correa:', maquina['modeloCorrea']),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
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

  Widget _buildModeloInfoRow(String titulo, String? modelo) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            titulo,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            modelo ?? 'No especificado',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // Diálogo para eliminar máquina
  void _mostrarDialogoEliminar(Map<String, dynamic> maquina) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar Máquina',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              color: theme.colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '¿Estás seguro de que deseas eliminar la máquina?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${maquina['patente']} - ${maquina['modelo']}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (mounted) {
                setState(() {
                  _maquinas.removeWhere((m) => m['id'] == maquina['id']);
                  _aplicarFiltros();
                });

                await guardarMaquinas(_maquinas);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Máquina eliminada con éxito'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final isHorizontal = mediaQuery.size.width > mediaQuery.size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Máquinas Registradas'),
        centerTitle: true,
        // Asegurar que el botón de regreso funcione
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Modelos de filtros y revisiones',
            onPressed: () {
              _mostrarDialogoModelos();
            },
          ),

          // Botón para mostrar panel de filtros
          IconButton(
            icon: Icon(_mostrarPanelFiltros ? Icons.filter_alt_off : Icons.filter_alt),
            tooltip: _mostrarPanelFiltros ? 'Ocultar filtros' : 'Mostrar filtros',
            onPressed: () {
              if (mounted) {
                setState(() {
                  _mostrarPanelFiltros = !_mostrarPanelFiltros;
                });
              }
            },
          ),

          // Botón de opciones de visualización
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility),
            tooltip: 'Opciones de visualización',
            onSelected: (value) {
              if (mounted) {
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
              }
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

          // Botón de tema
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            tooltip: 'Cambiar tema',
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: _cargando
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Cargando máquinas...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Panel de búsqueda y filtros (condicional)
          if (_mostrarPanelFiltros) _buildFilterPanel(theme),

          // Lista de máquinas
          Expanded(
            child: _maquinas.isEmpty
                ? _buildMensajeVacio(theme)
                : isHorizontal
                ? _buildHorizontalLayout(theme)
                : _buildVerticalLayout(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditMaquinaScreen(
                onSave: (nuevaMaquina) {
                  if (mounted) {
                    setState(() {
                      // Si ya existe la máquina, actualizarla
                      int index = _maquinas.indexWhere((m) => m['id'] == nuevaMaquina['id']);
                      if (index >= 0) {
                        _maquinas[index] = nuevaMaquina;
                      } else {
                        // Si no existe, agregarla
                        _maquinas.add(nuevaMaquina);
                      }
                      _aplicarFiltros();
                    });
                    guardarMaquinas(_maquinas);
                  }
                },
              ),
            ),
          ).then((_) {
            if (mounted) {
              _cargarMaquinas();
            }
          });
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Agregar Nueva Máquina',
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return FadeInDown(
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Campo de búsqueda
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por patente, modelo, número de máquina o VIN...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (valor) {
                setState(() {
                  _textoFiltro = valor;
                  _aplicarFiltros();
                });
              },
            ),

            const SizedBox(height: 16),

            // Opciones de filtro
            Row(
              children: [
                FilterChip(
                  label: const Text('Solo vencidas'),
                  selected: _mostrarSoloVencidos,
                  onSelected: (selected) {
                    setState(() {
                      _mostrarSoloVencidos = selected;
                      if (selected) {
                        _mostrarSoloProximos = false;
                      }
                      _aplicarFiltros();
                    });
                  },
                  selectedColor: Colors.red.withOpacity(0.2),
                  checkmarkColor: Colors.red,
                  avatar: _mostrarSoloVencidos ? const Icon(Icons.warning, size: 18, color: Colors.red) : null,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Próximas a vencer'),
                  selected: _mostrarSoloProximos,
                  onSelected: (selected) {
                    setState(() {
                      _mostrarSoloProximos = selected;
                      if (selected) {
                        _mostrarSoloVencidos = false;
                      }
                      _aplicarFiltros();
                    });
                  },
                  selectedColor: Colors.orange.withOpacity(0.2),
                  checkmarkColor: Colors.orange,
                  avatar: _mostrarSoloProximos ? const Icon(Icons.access_time, size: 18, color: Colors.orange) : null,
                ),
                const Spacer(),

                if (_mostrarSoloProximos || _mostrarSoloVencidos || _textoFiltro.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _mostrarSoloVencidos = false;
                        _mostrarSoloProximos = false;
                        _textoFiltro = '';
                        _aplicarFiltros();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Limpiar filtros'),
                  ),
              ],
            ),

            // Mostrar resultados de filtro
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mostrando ${_maquinasFiltradas.length} de ${_maquinas.length} máquinas',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout(ThemeData theme) {
    return Row(
      children: [
        // Panel lateral con lista de máquinas
        Container(
          width: MediaQuery.of(context).size.width * 0.3,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _cargarMaquinas,
                  child: _maquinasFiltradas.isEmpty
                      ? _buildEmptyListMessage(theme)
                      : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _maquinasFiltradas.length,
                    itemBuilder: (context, index) {
                      // Verificación de seguridad adicional
                      if (index < 0 || index >= _maquinasFiltradas.length) {
                        return const SizedBox.shrink();
                      }

                      final maquina = _maquinasFiltradas[index];
                      final bool estaSeleccionada = index == _maquinaSeleccionadaIndex &&
                          _maquinaSeleccionadaIndex < _maquinasFiltradas.length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: estaSeleccionada
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: estaSeleccionada
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: estaSeleccionada ? 2 : 0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getEstadoColor(maquina).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.directions_bus,
                              color: _getEstadoColor(maquina),
                            ),
                          ),
                          title: Text(
                            maquina['patente'] ?? 'Sin patente',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: estaSeleccionada
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(maquina['modelo'] ?? 'Sin modelo'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: _getColorFecha(maquina['fechaRevisionTecnica']),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatearFecha(maquina['fechaRevisionTecnica']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getColorFecha(maquina['fechaRevisionTecnica']),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            if (mounted && index < _maquinasFiltradas.length) {
                              setState(() {
                                _maquinaSeleccionadaIndex = index;
                              });
                            }
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

        // Panel de detalle de la máquina seleccionada
        Expanded(
          child: _buildDetailPanel(theme),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(ThemeData theme) {
    if (_maquinasFiltradas.isEmpty) {
      return _buildEmptyDetailPanel(theme);
    }

    if (_maquinaSeleccionadaIndex < 0 || _maquinaSeleccionadaIndex >= _maquinasFiltradas.length) {
      return _buildEmptyDetailPanel(theme);
    }

    try {
      final maquina = _maquinasFiltradas[_maquinaSeleccionadaIndex];
      return _buildMachineDetail(maquina, theme);
    } catch (e) {
      print('Error al mostrar detalle de máquina: $e');
      return _buildEmptyDetailPanel(theme);
    }
  }

  Widget _buildEmptyListMessage(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _mostrarSoloVencidos ? Icons.warning :
            _mostrarSoloProximos ? Icons.access_time : Icons.search,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _textoFiltro.isNotEmpty || _mostrarSoloVencidos || _mostrarSoloProximos
                ? 'No se encontraron máquinas\ncon los filtros aplicados'
                : 'No hay máquinas registradas',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDetailPanel(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Selecciona una máquina\npara ver sus detalles',
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMachineDetail(Map<String, dynamic> maquina, ThemeData theme) {
    if (maquina.isEmpty) {
      return _buildEmptyDetailPanel(theme);
    }

    final List<String> fotos = maquina['fotos'] != null ? List<String>.from(maquina['fotos']) : [];

    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.background,
      child: SingleChildScrollView(
        // Agregar physics para evitar problemas de scroll
        physics: const BouncingScrollPhysics(),
        child: Column(
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
                    color: _getEstadoColor(maquina).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 48,
                    color: _getEstadoColor(maquina),
                  ),
                ),
                const SizedBox(width: 24),

                // Información principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              maquina['patente'] ?? 'Sin patente',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildStatusBadge(maquina['estado'] ?? 'Sin estado'),
                        ],
                      ),
                      Text(
                        maquina['modelo'] ?? 'Sin modelo',
                        style: theme.textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${maquina['id'] ?? 'No especificado'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            theme: theme,
                            icon: Icons.people,
                            label: 'Capacidad',
                            value: '${maquina['capacidad'] ?? 0} pasajeros',
                          ),
                          _buildInfoChip(
                            theme: theme,
                            icon: Icons.speed,
                            label: 'Kilometraje',
                            value: '${maquina['kilometraje'] ?? 0} km',
                          ),
                          if (maquina['bin'] != null && maquina['bin'].toString().isNotEmpty)
                            _buildInfoChip(
                              theme: theme,
                              icon: Icons.credit_card,
                              label: 'BIN',
                              value: maquina['bin'],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Botones de acción
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: theme.colorScheme.primary,
                      ),
                      tooltip: 'Editar máquina',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditMaquinaScreen(
                              maquinaExistente: maquina,
                              onSave: (maquinaActualizada) {
                                if (mounted) {
                                  setState(() {
                                    final index = _maquinas.indexWhere(
                                            (m) => m['id'] == maquinaActualizada['id']
                                    );
                                    if (index != -1) {
                                      _maquinas[index] = maquinaActualizada;
                                      _aplicarFiltros();
                                    }
                                  });
                                  guardarMaquinas(_maquinas);
                                }
                              },
                            ),
                          ),
                        ).then((_) {
                          if (mounted) {
                            _cargarMaquinas();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: 'Eliminar máquina',
                      onPressed: () {
                        _mostrarDialogoEliminar(maquina);
                      },
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: Icon(
                        Icons.comment,
                        color: theme.colorScheme.secondary,
                      ),
                      tooltip: 'Editar comentarios',
                      onPressed: () {
                        _agregarComentario(maquina);
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Revisión técnica
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getColorFecha(maquina['fechaRevisionTecnica']).withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.safety_check,
                        color: _getColorFecha(maquina['fechaRevisionTecnica']),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Revisión Técnica',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getColorFecha(maquina['fechaRevisionTecnica']),
                        ),
                      ),
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
                            'Fecha de revisión:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatearFecha(maquina['fechaRevisionTecnica']),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getColorFecha(maquina['fechaRevisionTecnica']),
                            ),
                          ),
                        ],
                      ),
                      _buildDaysRemainingIndicator(maquina['fechaRevisionTecnica']),
                    ],
                  ),
                ],
              ),
            ),

            if (_mostrarFiltros) ...[
              const SizedBox(height: 32),
              _buildFiltersSection(maquina, theme),
            ],

            if (_mostrarOtrasRevisiones) ...[
              const SizedBox(height: 32),
              _buildOtrasRevisionesSection(maquina, theme),
            ],

            if (_mostrarComentarios) ...[
              const SizedBox(height: 32),
              _buildComentariosSection(maquina, fotos, theme),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection(Map<String, dynamic> maquina, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtros',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Filtro de Aceite
            Expanded(
              child: _buildFilterCard(
                theme: theme,
                title: 'Filtro de Aceite',
                model: maquina['modeloFiltroAceite'] ?? 'No especificado',
                date: maquina['fechaCambioFiltroAceite'],
                icon: Icons.oil_barrel,
              ),
            ),
            const SizedBox(width: 16),
            // Filtro de Aire
            Expanded(
              child: _buildFilterCard(
                theme: theme,
                title: 'Filtro de Aire',
                model: maquina['modeloFiltroAire'] ?? 'No especificado',
                date: maquina['fechaCambioFiltroAire'],
                icon: Icons.air,
              ),
            ),
            const SizedBox(width: 16),
            // Filtro de Petróleo
            Expanded(
              child: _buildFilterCard(
                theme: theme,
                title: 'Filtro de Petróleo',
                model: maquina['modeloFiltroPetroleo'] ?? 'No especificado',
                date: maquina['fechaCambioFiltroPetroleo'],
                icon: Icons.local_gas_station,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtrasRevisionesSection(Map<String, dynamic> maquina, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Otras Revisiones',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Decantador
            Expanded(
              child: _buildFilterCard(
                theme: theme,
                title: 'Decantador',
                model: maquina['modeloDecantador'] ?? 'No especificado',
                date: maquina['fechaRevisionDecantador'],
                icon: Icons.water_drop,
              ),
            ),
            const SizedBox(width: 16),
            // Mostrar primera correa (si existe)
            if (maquina['correas'] != null && (maquina['correas'] as List).isNotEmpty)
              Expanded(
                child: _buildFilterCard(
                  theme: theme,
                  title: 'Correa Principal',
                  model: (maquina['correas'] as List).first['modelo'] ?? 'No especificado',
                  date: (maquina['correas'] as List).first['fecha'],
                  icon: Icons.settings_input_component,
                ),
              )
            else if (maquina['modeloCorrea'] != null)
              Expanded(
                child: _buildFilterCard(
                  theme: theme,
                  title: 'Correa',
                  model: maquina['modeloCorrea'] ?? 'No especificado',
                  date: maquina['fechaRevisionCorrea'],
                  icon: Icons.settings_input_component,
                ),
              )
            else
              const Expanded(child: SizedBox()),
            // Espacio para mantener la simetría
            const Expanded(child: SizedBox()),
          ],
        ),

        // Mostrar correas adicionales (si hay más de una)
        if (maquina['correas'] != null && (maquina['correas'] as List).length > 1) ...[
          const SizedBox(height: 16),
          _buildCorreasAdicionalesSection(maquina, theme),
        ],
      ],
    );
  }

  Widget _buildCorreasAdicionalesSection(Map<String, dynamic> maquina, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Correas adicionales',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
            ),
            itemCount: (maquina['correas'] as List).length - 1,
            itemBuilder: (context, i) {
              final index = i + 1; // Empezar desde la segunda correa
              final correa = (maquina['correas'] as List)[index];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getColorFecha(correa['fecha']).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_input_component,
                      color: _getColorFecha(correa['fecha']),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Correa ${index + 1}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Modelo: ${correa['modelo'] ?? 'No especificado'}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatearFecha(correa['fecha']),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getColorFecha(correa['fecha']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComentariosSection(Map<String, dynamic> maquina, List<String> fotos, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comentarios y Fotos',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comentarios:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _agregarComentario(maquina),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar comentarios'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildComentarioContainer(maquina, theme),
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildFotosSection(fotos, theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComentarioContainer(Map<String, dynamic> maquina, ThemeData theme) {
    if (maquina['comentario'] != null && maquina['comentario'].toString().isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          maquina['comentario'],
          style: theme.textTheme.bodyLarge,
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          'No hay comentarios para esta máquina.',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }
  }

  Widget _buildFotosSection(List<String> fotos, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fotos adjuntas:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
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
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(fotos[index]),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.broken_image,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard({
    required ThemeData theme,
    required String title,
    required String model,
    required String? date,
    required IconData icon,
  }) {
    final Color color = _getColorFecha(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Modelo:',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            model,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Text(
            'Último cambio:',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            _formatearFecha(date),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysRemainingIndicator(String? fechaIso) {
    final theme = Theme.of(context);

    if (fechaIso == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Sin fecha programada',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    try {
      final DateTime fechaRevision = DateTime.parse(fechaIso);
      final DateTime ahora = DateTime.now();
      final int dias = fechaRevision.difference(ahora).inDays;

      final bool esVencido = dias < 0;
      final String textoMostrar = esVencido
          ? 'Vencido hace ${-dias} días'
          : (dias == 0 ? 'Vence hoy' : 'Faltan $dias días');

      final Color color = dias < 0
          ? Colors.red
          : (dias <= 30 ? Colors.orange : Colors.green);

      final IconData icon = esVencido
          ? Icons.warning
          : (dias <= 30 ? Icons.access_time : Icons.check_circle);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              textoMostrar,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.error),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'Fecha inválida',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    IconData badgeIcon;

    switch (status.toLowerCase()) {
      case 'activo':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        break;
      case 'en mantenimiento':
        badgeColor = Colors.orange;
        badgeIcon = Icons.engineering;
        break;
      case 'fuera de servicio':
        badgeColor = Colors.red;
        badgeIcon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 16, color: badgeColor),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalLayout(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _cargarMaquinas,
      child: _maquinasFiltradas.isEmpty
          ? ListView(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _mostrarSoloVencidos ? Icons.warning :
                    _mostrarSoloProximos ? Icons.access_time : Icons.search,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _textoFiltro.isNotEmpty || _mostrarSoloVencidos || _mostrarSoloProximos
                        ? 'No se encontraron máquinas con los filtros aplicados'
                        : 'No hay máquinas registradas',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_textoFiltro.isNotEmpty || _mostrarSoloVencidos || _mostrarSoloProximos)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _mostrarSoloVencidos = false;
                          _mostrarSoloProximos = false;
                          _textoFiltro = '';
                          _aplicarFiltros();
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            ),
          ),
        ],
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _maquinasFiltradas.length,
        itemBuilder: (context, index) {
          if (index >= _maquinasFiltradas.length) return const SizedBox();

          final maquina = _maquinasFiltradas[index];

          return MachineCard(
            machine: maquina,
            isSelected: false,
            onTap: () {
              // En la versión móvil, mostrar el detalle en pantalla completa
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _buildMobileDetailScreen(maquina),
                ),
              ).then((_) => _cargarMaquinas());
            },
            onEdit: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditMaquinaScreen(
                    maquinaExistente: maquina,
                    onSave: (maquinaActualizada) {
                      if (mounted) {
                        setState(() {
                          final idx = _maquinas.indexWhere(
                                  (m) => m['id'] == maquinaActualizada['id']
                          );
                          if (idx != -1) {
                            _maquinas[idx] = maquinaActualizada;
                            _aplicarFiltros();
                          }
                        });
                        guardarMaquinas(_maquinas);
                      }
                    },
                  ),
                ),
              ).then((_) => _cargarMaquinas());
            },
            onDelete: () {
              _mostrarDialogoEliminar(maquina);
            },
          );
        },
      ),
    );
  }

  // Pantalla de detalle para versión móvil
  Widget _buildMobileDetailScreen(Map<String, dynamic> maquina) {
    return Scaffold(
      appBar: AppBar(
        title: Text(maquina['patente'] ?? 'Detalles de Máquina'),
        actions: [
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
                      if (mounted) {
                        setState(() {
                          final index = _maquinas.indexWhere(
                                  (m) => m['id'] == maquinaActualizada['id']
                          );
                          if (index != -1) {
                            _maquinas[index] = maquinaActualizada;
                            _aplicarFiltros();
                          }
                        });
                        guardarMaquinas(_maquinas);
                        Navigator.pop(context); // Regresar a la pantalla de detalle
                      }
                    },
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _mostrarDialogoEliminar(maquina);
              } else if (value == 'comment') {
                _agregarComentario(maquina);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'comment',
                child: ListTile(
                  leading: Icon(Icons.comment),
                  title: Text('Editar comentarios'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Eliminar máquina', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildMachineDetail(maquina, Theme.of(context)),
    );
  }

  Widget _buildMensajeVacio(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay máquinas registradas',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Utiliza el botón + para agregar una nueva máquina',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditMaquinaScreen(
                    onSave: (nuevaMaquina) {
                      if (mounted) {
                        setState(() {
                          _maquinas.add(nuevaMaquina);
                          _aplicarFiltros();
                        });
                        guardarMaquinas(_maquinas);
                      }
                    },
                  ),
                ),
              ).then((_) => _cargarMaquinas());
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar Máquina'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Función para obtener color según el estado
  Color _getEstadoColor(Map<String, dynamic> maquina) {
    final diasRevision = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);

    // Si la revisión está vencida o próxima a vencer, mostrar color de alerta
    if (diasRevision != null) {
      if (diasRevision < 0) {
        return Colors.red; // Vencida
      } else if (diasRevision <= 30) {
        return Colors.orange; // Próxima a vencer
      }
    }

    // Si no, usar el color según el estado operativo
    final estado = maquina['estado'] ?? '';

    if (estado == 'Activo') {
      return Colors.green;
    } else if (estado == 'En mantenimiento') {
      return Colors.orange;
    } else if (estado == 'Fuera de servicio') {
      return Colors.red;
    }

    return Colors.grey;
  }

  // Función para obtener color según una fecha ISO
  Color _getColorFecha(String? fechaIso) {
    if (fechaIso == null) {
      return Colors.grey;
    }

    try {
      final DateTime fecha = DateTime.parse(fechaIso);
      final DateTime ahora = DateTime.now();
      final int diasRestantes = fecha.difference(ahora).inDays;

      if (diasRestantes < 0) {
        return Colors.red;
      } else if (diasRestantes <= 30) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    } catch (e) {
      return Colors.grey;
    }
  }
}
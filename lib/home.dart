import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'maquina_screen.dart';
import 'edit_maquina_screen.dart';
import 'settings_screen.dart';
import 'generate_excel_screen.dart';
import 'export_document_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

  bool _hayDatosMaquinas = false;
  bool _cargando = true;
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Variables para almacenar estadísticas
  int _totalMaquinas = 0;
  int _revisionesProximas = 0;
  int _revisionesVencidas = 0;

  // Para mostrar últimas actualizaciones
  List<Map<String, dynamic>> _ultimasMaquinasActualizadas = [];
  DateTime? _ultimaActualizacion;

  // Timer para actualización automática
  Timer? _actualizacionTimer;

  @override
  void initState() {
    super.initState();
    _verificarDatos();
    _registerShortcuts();

    // Iniciar actualización automática cada 60 segundos
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _verificarDatos();
    });
  }

  @override
  void dispose() {
    _actualizacionTimer?.cancel();
    super.dispose();
  }

  void _registerShortcuts() {
    ServicesBinding.instance.keyboard.addHandler((KeyEvent event) {
      if (event is! KeyDownEvent) return false;

      try {
        if (HardwareKeyboard.instance.isControlPressed) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.keyM:
              if (_hayDatosMaquinas) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navegarAMaquinas();
                });
                return true;
              }
              break;

            case LogicalKeyboardKey.keyN:
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _editarMaquina();
              });
              return true;

            case LogicalKeyboardKey.keyE:
              if (_hayDatosMaquinas) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navegarAExportarExcel();
                });
                return true;
              }
              break;

            case LogicalKeyboardKey.keyR:
              if (_hayDatosMaquinas) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navegarAGenerarReporte();
                });
                return true;
              }
              break;

            case LogicalKeyboardKey.keyS:
              if (_hayDatosMaquinas) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _navegarAExportarDocumento();
                });
                return true;
              }
              break;

            case LogicalKeyboardKey.keyI:
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navegarAImportarDocumento();
              });
              return true;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.f1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mostrarAyudaAtajos();
          });
          return true;
        }
      } catch (e) {
        print('Error en manejo de atajos de teclado: $e');
      }

      return false;
    });
  }

  void _mostrarAyudaAtajos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _verificarDatos() async {
    setState(() {
      _cargando = true;
    });

    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);
        final maquinas = maquinasJson.cast<Map<String, dynamic>>();

        // Calcular estadísticas
        int proximas = 0;
        int vencidas = 0;

        // Obtener las últimas máquinas actualizadas
        List<Map<String, dynamic>> maquinasOrdenadas = List.from(maquinas);

        maquinasOrdenadas.sort((a, b) {
            try {
            } catch (e) {}
          }

            try {
              return fechaB.compareTo(fechaA);
        });

        for (var maquina in maquinas) {
          if (maquina['fechaRevisionTecnica'] != null) {
            try {
              final DateTime fechaRevision = DateTime.parse(maquina['fechaRevisionTecnica']);
              final DateTime ahora = DateTime.now();
              final diferencia = fechaRevision.difference(ahora);

              if (diferencia.inDays < 0) {
                // Revisión vencida
                vencidas++;
              } else if (diferencia.inDays <= 30) {
                // Revisión próxima a vencer (30 días o menos)
                proximas++;
              }
            } catch (e) {
              print('Error al procesar fecha: $e');
            }
          }
        }

        setState(() {
          _hayDatosMaquinas = maquinas.isNotEmpty;
          _totalMaquinas = maquinas.length;
          _revisionesProximas = proximas;
          _revisionesVencidas = vencidas;
          _ultimasMaquinasActualizadas = maquinasOrdenadas.take(5).toList(); // Tomar las 5 más recientes
          _ultimaActualizacion = DateTime.now();
          _cargando = false;
        });
      } else {
        setState(() {
          _hayDatosMaquinas = false;
          _totalMaquinas = 0;
          _revisionesProximas = 0;
          _revisionesVencidas = 0;
          _ultimasMaquinasActualizadas = [];
          _cargando = false;
        });
      }
    } catch (e) {
      print('Error al verificar datos: $e');
      setState(() {
        _hayDatosMaquinas = false;
        _totalMaquinas = 0;
        _revisionesProximas = 0;
        _revisionesVencidas = 0;
        _ultimasMaquinasActualizadas = [];
        _cargando = false;
      });
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

  void _navegarAMaquinas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MaquinaScreen()),
    ).then((_) {
      _verificarDatos();
    });
  }

  void _editarMaquina() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMaquinaScreen(
          onSave: (nuevaMaquina) {
            setState(() {
              _hayDatosMaquinas = true;
            });
          },
        ),
      ),
    ).then((_) {
      _verificarDatos();
    });
  }

  void _navegarAConfiguracion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      _verificarDatos();
    });
  }

  void _navegarAExportarExcel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GenerateExcelScreen(),
      ),
    );
  }

  void _navegarAExportarDocumento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExportDocumentScreen(),
      ),
    );
  }

  void _navegarAGenerarReporte() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GenerarReporteScreen(),
      ),
    );
  }

  void _navegarAImportarDocumento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImportDocumentScreen(),
      ),
    ).then((resultado) {
      if (resultado == true) {
        _verificarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos importados con éxito'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _navegarAImportarExcel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImportExcelScreen(),
      ),
    ).then((resultado) {
      if (resultado == true) {
        _verificarDatos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = mediaQuery.size.shortestSide >= 600;
    final isWindows = Platform.isWindows;
    final useDesktopLayout = isWindows || (isLandscape && isTablet);

    return Scaffold(
      key: _scaffoldKey,
      body: _cargando
          : useDesktopLayout
    );
  }

    return AppBar(
      centerTitle: false,
      foregroundColor: Colors.white,
      elevation: 4,
      actions: [
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),

        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Configuración',
          onPressed: _navegarAConfiguracion,
        ),

        PopupMenuButton<String>(
          icon: CircleAvatar(
            backgroundColor: Colors.white24,
          ),
          tooltip: 'Opciones de usuario',
          onSelected: (value) {
            // Implementar opciones de usuario
          },
          itemBuilder: (context) => [
              value: 'profile',
              child: ListTile(
              ),
            ),
              value: 'help',
              child: ListTile(
              ),
            ),
              value: 'about',
              child: ListTile(
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
    );
  }

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.directions_bus,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                    Text(
                      'Sistema de Gestión de Flota',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
          ),

          _buildDrawerItem(
            icon: Icons.directions_bus_filled,
            title: 'Ver Máquinas',
            onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            icon: Icons.add_circle_outline,
            title: 'Agregar Máquina',
            onTap: _editarMaquina,
          ),
          _buildDrawerItem(
            icon: Icons.assessment,
            title: 'Generar Reporte',
            onTap: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            icon: Icons.table_chart,
            title: 'Exportar a Excel',
            onTap: _hayDatosMaquinas ? _navegarAExportarExcel : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            icon: Icons.save_alt,
            title: 'Crear Respaldo',
            onTap: _hayDatosMaquinas ? _navegarAExportarDocumento : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            icon: Icons.upload_file,
            title: 'Importar Documento',
            onTap: _navegarAImportarDocumento,
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Configuración',
            onTap: _navegarAConfiguracion,
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(
        icon,
      ),
      title: Text(
        title,
        style: TextStyle(
      ),
        ),
      onTap: enabled
          ? () {
        Navigator.pop(context);
        onTap?.call();
      }
          : null,
      enabled: enabled,
    );
  }

    return Row(
      children: [

        Expanded(
          child: Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

    return Container(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mantenimiento Suray',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [

                _buildSidebarItem(
                  icon: Icons.directions_bus_filled,
                  title: 'Ver Máquinas',
                  isSelected: _selectedIndex == 0,
                  onTap: _hayDatosMaquinas ? () {
                    setState(() => _selectedIndex = 0);
                    _navegarAMaquinas();
                  } : null,
                  enabled: _hayDatosMaquinas,
                ),

                _buildSidebarItem(
                  icon: Icons.add_circle_outline,
                  title: 'Agregar Máquina',
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    _editarMaquina();
                  },
                ),

                _buildSidebarItem(
                  icon: Icons.assessment,
                  title: 'Reportes',
                  isSelected: _selectedIndex == 2,
                  onTap: _hayDatosMaquinas ? () {
                    setState(() => _selectedIndex = 2);
                    _navegarAGenerarReporte();
                  } : null,
                  enabled: _hayDatosMaquinas,
                ),


                _buildSidebarItem(
                  icon: Icons.table_chart,
                  title: 'Exportar a Excel',
                  isSelected: _selectedIndex == 3,
                  onTap: _hayDatosMaquinas ? () {
                    setState(() => _selectedIndex = 3);
                    _navegarAExportarExcel();
                  } : null,
                  enabled: _hayDatosMaquinas,
                ),

                _buildSidebarItem(
                  icon: Icons.save_alt,
                  title: 'Crear Respaldo',
                  isSelected: _selectedIndex == 4,
                  onTap: _hayDatosMaquinas ? () {
                    setState(() => _selectedIndex = 4);
                    _navegarAExportarDocumento();
                  } : null,
                  enabled: _hayDatosMaquinas,
                ),

                _buildSidebarItem(
                  icon: Icons.upload_file,
                  title: 'Importar Documento',
                  isSelected: _selectedIndex == 5,
                  onTap: () {
                    setState(() => _selectedIndex = 5);
                    _navegarAImportarDocumento();
                  },
                ),

                _buildSidebarItem(
                  icon: Icons.upload_file,
                  title: 'Importar Excel',
                  isSelected: _selectedIndex == 6,
                  onTap: () {
                    setState(() => _selectedIndex = 6);
                    _navegarAImportarExcel();
                  },
                ),


                _buildSidebarItem(
                  icon: Icons.settings,
                  title: 'Configuración',
                  isSelected: _selectedIndex == 8,
                  onTap: () {
                    setState(() => _selectedIndex = 8);
                    _navegarAConfiguracion();
                  },
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© ${DateTime.now().year} Suray',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    String? shortcut,
    required bool isSelected,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: !enabled
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: !enabled
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        dense: true,
        onTap: enabled ? onTap : null,
        selected: isSelected,
        enabled: enabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

    return Container(
      padding: const EdgeInsets.all(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    'Panel de Control',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bienvenido al sistema de gestión de flota de buses',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _editarMaquina,
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Máquina'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
                    icon: const Icon(Icons.assessment),
                    label: const Text('Ver Reportes'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_hayDatosMaquinas) ...[
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.directions_bus,
          title: 'Total de Máquinas',
          value: '$_totalMaquinas',
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          icon: Icons.warning,
          title: 'Revisiones Próximas',
          value: '$_revisionesProximas',
          color: Colors.orange,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          icon: Icons.dangerous,
          title: 'Revisiones Vencidas',
          value: '$_revisionesVencidas',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget para mostrar las últimas máquinas actualizadas
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_ultimaActualizacion != null)
                  Text(
                    'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(_ultimaActualizacion!)}',
                    style: TextStyle(
                      fontSize: 12,
                  ),
              ),
          ],
        ),

        Expanded(
          child: _ultimasMaquinasActualizadas.isEmpty
                  child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ),
                                const SizedBox(height: 16),
                          Text(
                          ),
                          ),
                        ],
                      ),
                          itemCount: _ultimasMaquinasActualizadas.length,
                          itemBuilder: (context, index) {
                            final maquina = _ultimasMaquinasActualizadas[index];
                            String fechaTexto = '';

                              try {
                                final fecha = DateTime.parse(maquina['fechaRevisionTecnica']);
                                fechaTexto = DateFormat('dd/MM/yyyy').format(fecha);
                              } catch (e) {
                                fechaTexto = 'Fecha no disponible';
                              }
                            } else {
                            }

                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditMaquinaScreen(
                                        maquinaExistente: maquina,
                                        onSave: (maquinaActualizada) {
                                        },
                                      ),
                                    ),
                                  );
                                },
                                        child: Column(
                                          children: [
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                ),
                                                const SizedBox(width: 4),
                                                ],
                                              ),
                                          ],
                                        ),
          decoration: BoxDecoration(
        ),
              ),
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
        ),

    return Container(
      ),
      ),
    );
          ),
            ),
          ),
            ),
            ),
          ),
        ],
    );
  }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          if (_hayDatosMaquinas)

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: isLandscape
            ),
          ),

        ],
      ),
    );
  }

    return Container(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  'Mantenimiento Buses Suray',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sistema de Gestión de Flota',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          ),

          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: const Icon(Icons.menu),
            tooltip: 'Menú',
          ),
        ],
      ),
    );
  }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
                icon: const Icon(Icons.assessment, color: Colors.white, size: 16),
                label: const Text(
                  'Ver Reporte',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'La información de tu flota está lista para ser consultada.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              _buildMobileStatCard(
                title: 'Total',
                value: '$_totalMaquinas',
                icon: Icons.directions_bus,
              ),
              _buildMobileStatCard(
                title: 'Próximas',
                value: '$_revisionesProximas',
                icon: Icons.warning,
              ),
              _buildMobileStatCard(
                title: 'Vencidas',
                value: '$_revisionesVencidas',
                icon: Icons.dangerous,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

      crossAxisCount: 2,
      childAspectRatio: 1.0,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          title: 'Ver Máquinas',
          icon: Icons.directions_bus_filled,
          description: 'Consulta la información detallada de todas las máquinas',
          onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
        ),
        _buildMenuCard(
          title: 'Editar Máquina',
          icon: Icons.edit_outlined,
          description: 'Añade o modifica información de las máquinas',
          onTap: _editarMaquina,
        ),
        _buildMenuCard(
          title: 'Exportar a Excel',
          icon: Icons.table_chart,
          color: const Color(0xFF00897B),
          description: 'Genera un archivo Excel con los datos e imágenes',
          onTap: _hayDatosMaquinas ? _navegarAExportarExcel : null,
        ),
      ],
  }

      crossAxisCount: 3,
      childAspectRatio: 1.3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          title: 'Ver Máquinas',
          icon: Icons.directions_bus_filled,
          description: 'Consulta la información detallada',
          onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
        ),
        _buildMenuCard(
          title: 'Editar Máquina',
          icon: Icons.edit_outlined,
          description: 'Añade o modifica información',
          onTap: _editarMaquina,
        ),
        _buildMenuCard(
          title: 'Generar Reporte',
          icon: Icons.assessment,
          description: 'Visualiza informes y estadísticas',
          onTap: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
        ),
        _buildMenuCard(
          title: 'Exportar a Excel',
          icon: Icons.table_chart,
          color: const Color(0xFF00897B),
          description: 'Genera un Excel con datos e imágenes',
          onTap: _hayDatosMaquinas ? _navegarAExportarExcel : null,
        ),
        _buildMenuCard(
          icon: Icons.save_alt,
          color: const Color(0xFF7E57C2),
          description: 'Crea un respaldo completo',
          onTap: _hayDatosMaquinas ? _navegarAExportarDocumento : null,
        ),
      ],
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            width: 1.5,
          ),
        ),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    description,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      ),
    );
  }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ${DateTime.now().year} Suray',
            style: TextStyle(
              fontSize: 12,
            ),
          ),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
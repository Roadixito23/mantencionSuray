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
import 'generar_reporte_screen.dart';
import 'import_document_screen.dart';
import 'import_excel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hayDatosMaquinas = false;
  bool _cargando = true;
  int _selectedIndex = 0;
  bool _isHovering = false;
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
    // Cancelar el timer al destruir el widget
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
        title: const Text('Atajos de Teclado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Ctrl+M: Ver Máquinas'),
            Text('Ctrl+N: Agregar Máquina'),
            Text('Ctrl+E: Exportar a Excel'),
            Text('Ctrl+R: Generar Reporte'),
            Text('Ctrl+S: Crear Respaldo'),
            Text('Ctrl+I: Importar Documento'),
            Text('F1: Mostrar esta ayuda'),
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
        // Ordenar por fecha de modificación si existe, o usar algún criterio alternativo
        List<Map<String, dynamic>> maquinasOrdenadas = List.from(maquinas);

        // Intentar ordenar por alguna fecha disponible (priorizar fechas recientes)
        maquinasOrdenadas.sort((a, b) {
          // Tratar de encontrar fechas de modificación o de revisiones recientes
          DateTime? fechaA;
          DateTime? fechaB;

          // Prioridad 1: Fecha de últimas modificaciones si existiera
          // Prioridad 2: Fecha de revisión técnica
          // Prioridad 3: Cualquier otra fecha disponible

          if (a['fechaRevisionTecnica'] != null) {
            try {
              fechaA = DateTime.parse(a['fechaRevisionTecnica']);
            } catch (e) {}
          }

          if (b['fechaRevisionTecnica'] != null) {
            try {
              fechaB = DateTime.parse(b['fechaRevisionTecnica']);
            } catch (e) {}
          }

          // Si no se encontraron fechas válidas, mantener el orden original
          if (fechaA == null && fechaB == null) return 0;
          if (fechaA == null) return 1; // B es más reciente
          if (fechaB == null) return -1; // A es más reciente

          // Orden descendente (más reciente primero)
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
      appBar: useDesktopLayout ? _buildWindowsAppBar() : null,
      drawer: useDesktopLayout ? null : _buildMobileDrawer(),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : useDesktopLayout
          ? _buildWindowsLayout()
          : _buildMobileLayout(isLandscape),
    );
  }

  PreferredSizeWidget _buildWindowsAppBar() {
    return AppBar(
      title: const Text('Mantenimiento Buses Suray'),
      centerTitle: false,
      backgroundColor: Colors.blue.shade800,
      foregroundColor: Colors.white,
      elevation: 4,
      actions: [
        Container(
          width: 200,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
              hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
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
            child: Icon(Icons.person, color: Colors.white),
          ),
          tooltip: 'Opciones de usuario',
          onSelected: (value) {
            // Implementar opciones de usuario
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text('Mi Perfil'),
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: ListTile(
                leading: Icon(Icons.help),
                title: Text('Ayuda'),
              ),
            ),
            const PopupMenuItem(
              value: 'about',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Acerca de'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade700, Colors.blue.shade900],
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
                        color: Colors.blue.shade800,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Mantenimiento\nBuses Suray',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
          const Divider(),
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
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: Colors.grey.shade600,
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
        color: enabled ? Colors.blue.shade700 : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey,
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

  Widget _buildWindowsLayout() {
    return Row(
      children: [
        _buildWindowsSidebar(),

        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWindowsHeader(),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildUltimasActualizaciones(), // Mostrar últimas actualizaciones en lugar del panel de acciones rápidas
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsSidebar() {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Colors.blue.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mantenimiento Suray',
                  style: TextStyle(
                    color: Colors.blue.shade800,
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
                _buildSidebarCategory('GESTIÓN DE FLOTA'),

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

                _buildSidebarCategory('EXPORTACIÓN E IMPORTACIÓN'),

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

                _buildSidebarCategory('CONFIGURACIÓN'),

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
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© ${DateTime.now().year} Suray',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Colors.grey.shade600,
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

  Widget _buildSidebarCategory(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: !enabled
                ? Colors.grey.shade400
                : (isSelected ? Colors.blue.shade700 : Colors.grey.shade700),
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: !enabled
                  ? Colors.grey.shade400
                  : (isSelected ? Colors.blue.shade800 : Colors.grey.shade900),
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
      ),
    );
  }

  Widget _buildWindowsHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
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
                  const Text(
                    'Panel de Control',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bienvenido al sistema de gestión de flota de buses',
                    style: TextStyle(
                      color: Colors.grey.shade600,
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
            _buildQuickStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.directions_bus,
          title: 'Total de Máquinas',
          value: '$_totalMaquinas',
          color: Colors.blue,
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
          borderRadius: BorderRadius.circular(8),
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
                    color: Colors.grey.shade700,
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
  Widget _buildUltimasActualizaciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Últimas Actualizaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            if (_ultimaActualizacion != null)
              Text(
                'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(_ultimaActualizacion!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _ultimasMaquinasActualizadas.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay máquinas registradas',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _ultimasMaquinasActualizadas.length,
            itemBuilder: (context, index) {
              final maquina = _ultimasMaquinasActualizadas[index];
              String fechaTexto = '';

              if (maquina['fechaRevisionTecnica'] != null) {
                try {
                  final fecha = DateTime.parse(maquina['fechaRevisionTecnica']);
                  fechaTexto = DateFormat('dd/MM/yyyy').format(fecha);
                } catch (e) {
                  fechaTexto = 'Fecha no disponible';
                }
              } else {
                fechaTexto = 'Sin fecha de revisión';
              }

              // Ver si hay fotos para mostrar
              final List<String> fotos = maquina['fotos'] != null ? List<String>.from(maquina['fotos']) : [];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditMaquinaScreen(
                          maquinaExistente: maquina,
                          onSave: (maquinaActualizada) {
                            _verificarDatos(); // Actualizar datos al regresar
                          },
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.directions_bus,
                            color: Colors.blue.shade800,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          '${maquina['placa'] ?? 'Sin placa'} - ${maquina['modelo'] ?? 'Sin modelo'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${maquina['id'] ?? ''}'),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text('Revisión: $fechaTexto'),
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
                      ),

                      // Mostrar fotos si existen (en forma horizontal)
                      if (fotos.isNotEmpty) ...[
                        const Divider(height: 1),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(8),
                            itemCount: fotos.length,
                            itemBuilder: (context, fotoIndex) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(fotos[fotoIndex]),
                                    width: 120,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 120,
                                        height: 84,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isLandscape) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          if (_hayDatosMaquinas)
            _buildDashboard(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: isLandscape
                  ? _buildLandscapeGrid()
                  : _buildPortraitGrid(),
            ),
          ),

          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
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
                const Text(
                  'Mantenimiento Buses Suray',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                Text(
                  'Sistema de Gestión de Flota',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _navegarAConfiguracion,
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            color: Colors.grey.shade700,
          ),

          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: const Icon(Icons.menu),
            tooltip: 'Menú',
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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

  Widget _buildPortraitGrid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.0,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          title: 'Ver Máquinas',
          icon: Icons.directions_bus_filled,
          color: const Color(0xFF1976D2),
          description: 'Consulta la información detallada de todas las máquinas',
          onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
        ),
        _buildMenuCard(
          title: 'Editar Máquina',
          icon: Icons.edit_outlined,
          color: const Color(0xFF43A047),
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
        _buildMenuCard(
          title: 'Respaldo',
          icon: Icons.save_alt,
          color: const Color(0xFF7B1FA2),
          description: 'Crea un respaldo completo del sistema',
          onTap: _hayDatosMaquinas ? _navegarAExportarDocumento : null,
        ),
      ],
    );
  }

  Widget _buildLandscapeGrid() {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          title: 'Ver Máquinas',
          icon: Icons.directions_bus_filled,
          color: const Color(0xFF1976D2),
          description: 'Consulta la información detallada',
          onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
        ),
        _buildMenuCard(
          title: 'Editar Máquina',
          icon: Icons.edit_outlined,
          color: const Color(0xFF43A047),
          description: 'Añade o modifica información',
          onTap: _editarMaquina,
        ),
        _buildMenuCard(
          title: 'Generar Reporte',
          icon: Icons.assessment,
          color: const Color(0xFFFFA000),
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
          title: 'Respaldo',
          icon: Icons.save_alt,
          color: const Color(0xFF7E57C2),
          description: 'Crea un respaldo completo',
          onTap: _hayDatosMaquinas ? _navegarAExportarDocumento : null,
        ),
      ],
    );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDisabled ? Colors.grey.shade200 : color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDisabled ? Colors.grey.shade300 : color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey.shade200 : color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDisabled ? Colors.grey.shade400 : color,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDisabled ? Colors.grey.shade500 : const Color(0xFF263238),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDisabled ? Colors.grey.shade400 : Colors.grey.shade600,
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ${DateTime.now().year} Suray',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
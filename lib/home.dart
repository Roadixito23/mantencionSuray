import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:badges/badges.dart' as badges;
import 'maquina_screen.dart';
import 'edit_maquina_screen.dart';
import 'settings_screen.dart';
import 'generate_excel_screen.dart';
import 'export_document_screen.dart';
import 'import_document_screen.dart';
import 'import_excel_screen.dart';
import 'generar_reporte_screen.dart';
import 'providers/theme_provider.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _hayDatosMaquinas = false;
  bool _cargando = true;
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  // Variables para almacenar estadísticas
  int _totalMaquinas = 0;
  int _revisionesProximas = 0;
  int _revisionesVencidas = 0;
  int _maquinasActivas = 0;
  int _maquinasMantenimiento = 0;
  int _maquinasFueraServicio = 0;

  // Para mostrar últimas actualizaciones
  List<Map<String, dynamic>> _ultimasMaquinasActualizadas = [];
  DateTime? _ultimaActualizacion;

  // Timer para actualización automática
  Timer? _actualizacionTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _searchController.dispose();
    _tabController.dispose();
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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.keyboard, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Atajos de Teclado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAtajoItem(Icons.directions_bus, 'Ctrl+M: Ver Máquinas'),
            _buildAtajoItem(Icons.add_circle_outline, 'Ctrl+N: Agregar Máquina'),
            _buildAtajoItem(Icons.table_chart, 'Ctrl+E: Exportar a Excel'),
            _buildAtajoItem(Icons.assessment, 'Ctrl+R: Generar Reporte'),
            _buildAtajoItem(Icons.save_alt, 'Ctrl+S: Crear Respaldo'),
            _buildAtajoItem(Icons.upload_file, 'Ctrl+I: Importar Documento'),
            _buildAtajoItem(Icons.help_outline, 'F1: Mostrar esta ayuda'),
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

  Widget _buildAtajoItem(IconData icon, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium,
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
        int activas = 0;
        int mantenimiento = 0;
        int fueraServicio = 0;

        // Obtener las últimas máquinas actualizadas
        List<Map<String, dynamic>> maquinasOrdenadas = List.from(maquinas);

        // Ordenar por fecha de modificación si existe, o usar fechas de revisión como alternativa
        maquinasOrdenadas.sort((a, b) {
          // Prioridad 1: Fecha de modificación
          if (a['fechaModificacion'] != null && b['fechaModificacion'] != null) {
            try {
              final DateTime fechaA = DateTime.parse(a['fechaModificacion']);
              final DateTime fechaB = DateTime.parse(b['fechaModificacion']);
              // Orden descendente (más reciente primero)
              return fechaB.compareTo(fechaA);
            } catch (e) {}
          }

          // Prioridad 2: Fecha de revisión técnica
          if (a['fechaRevisionTecnica'] != null && b['fechaRevisionTecnica'] != null) {
            try {
              final DateTime fechaA = DateTime.parse(a['fechaRevisionTecnica']);
              final DateTime fechaB = DateTime.parse(b['fechaRevisionTecnica']);
              return fechaB.compareTo(fechaA);
            } catch (e) {}
          }

          // Sin fechas válidas para comparar
          return 0;
        });

        for (var maquina in maquinas) {
          // Contar por estado
          final estado = maquina['estado'] ?? '';
          if (estado == 'Activo') {
            activas++;
          } else if (estado == 'En mantenimiento') {
            mantenimiento++;
          } else if (estado == 'Fuera de servicio') {
            fueraServicio++;
          }

          // Contar por revisiones
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
          _maquinasActivas = activas;
          _maquinasMantenimiento = mantenimiento;
          _maquinasFueraServicio = fueraServicio;
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
          _maquinasActivas = 0;
          _maquinasMantenimiento = 0;
          _maquinasFueraServicio = 0;
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
        _maquinasActivas = 0;
        _maquinasMantenimiento = 0;
        _maquinasFueraServicio = 0;
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = mediaQuery.size.shortestSide >= 600;
    final isWindows = Platform.isWindows;
    final useDesktopLayout = isWindows || (isLandscape && isTablet);

    return Scaffold(
      key: _scaffoldKey,
      appBar: useDesktopLayout ? _buildWindowsAppBar(theme) : null,
      drawer: useDesktopLayout ? null : _buildMobileDrawer(theme),
      body: _cargando
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Cargando información...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      )
          : useDesktopLayout
          ? _buildWindowsLayout(theme)
          : _buildMobileLayout(isLandscape, theme),
    );
  }

  PreferredSizeWidget _buildWindowsAppBar(ThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.directions_bus,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text('Mantenimiento Buses Suray'),
        ],
      ),
      centerTitle: false,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      actions: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isSearchOpen ? 300 : 48,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: _isSearchOpen
              ? TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    _isSearchOpen = false;
                    _searchController.clear();
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: const TextStyle(color: Colors.white),
          )
              : IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Buscar',
            onPressed: () {
              setState(() {
                _isSearchOpen = true;
              });
            },
          ),
        ),

        const SizedBox(width: 8),

        badges.Badge(
          showBadge: (_revisionesProximas + _revisionesVencidas) > 0,
          badgeContent: Text(
            '${_revisionesProximas + _revisionesVencidas}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          position: badges.BadgePosition.topEnd(top: 8, end: 8),
          badgeStyle: badges.BadgeStyle(
            badgeColor: Colors.red,
            padding: const EdgeInsets.all(4),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notificaciones',
            onPressed: () {
              // Implementar visualización de notificaciones
            },
          ),
        ),

        IconButton(
          icon: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          tooltip: 'Cambiar tema',
          onPressed: () {
            themeProvider.toggleTheme();
          },
        ),

        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Configuración',
          onPressed: _navegarAConfiguracion,
        ),

        PopupMenuButton<String>(
          icon: CircleAvatar(
            backgroundColor: Colors.white24,
            child: const Icon(Icons.person, color: Colors.white),
          ),
          tooltip: 'Opciones de usuario',
          onSelected: (value) {
            // Implementar opciones de usuario
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person, color: theme.colorScheme.primary),
                title: const Text('Mi Perfil'),
              ),
            ),
            PopupMenuItem(
              value: 'help',
              child: ListTile(
                leading: Icon(Icons.help, color: theme.colorScheme.primary),
                title: const Text('Ayuda'),
              ),
            ),
            PopupMenuItem(
              value: 'about',
              child: ListTile(
                leading: Icon(Icons.info, color: theme.colorScheme.primary),
                title: const Text('Acerca de'),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMobileDrawer(ThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  Color.lerp(theme.colorScheme.primary, Colors.black, 0.3) ?? theme.colorScheme.primary.withOpacity(0.7)
                ],
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
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mantenimiento',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Buses Suray',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white.withOpacity(0.8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Sistema de Gestión de Flota',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildDrawerItem(
            theme: theme,
            icon: Icons.directions_bus_filled,
            title: 'Ver Máquinas',
            badge: _hayDatosMaquinas ? _totalMaquinas.toString() : null,
            onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            theme: theme,
            icon: Icons.add_circle_outline,
            title: 'Agregar Máquina',
            onTap: _editarMaquina,
          ),
          _buildDrawerItem(
            theme: theme,
            icon: Icons.assessment,
            title: 'Generar Reporte',
            badge: (_revisionesProximas + _revisionesVencidas) > 0
                ? '${_revisionesProximas + _revisionesVencidas}'
                : null,
            badgeColor: Colors.red,
            onTap: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            theme: theme,
            icon: Icons.table_chart,
            title: 'Exportar a Excel',
            onTap: _hayDatosMaquinas ? _navegarAExportarExcel : null,
            enabled: _hayDatosMaquinas,
          ),
          _buildDrawerItem(
            theme: theme,
            icon: Icons.save_alt,
            title: 'Crear Respaldo',
            onTap: _hayDatosMaquinas ? _navegarAExportarDocumento : null,
            enabled: _hayDatosMaquinas,
          ),
          const Divider(height: 32),
          _buildDrawerItem(
            theme: theme,
            icon: Icons.upload_file,
            title: 'Importar Documento',
            onTap: _navegarAImportarDocumento,
          ),
          _buildDrawerItem(
            theme: theme,
            icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            title: themeProvider.isDarkMode ? 'Modo Oscuro' : 'Modo Claro',
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.setDarkMode(value);
              },
              activeColor: theme.colorScheme.primary,
            ),
            onTap: () {
              themeProvider.toggleTheme();
            },
          ),
          _buildDrawerItem(
            theme: theme,
            icon: Icons.settings,
            title: 'Configuración',
            onTap: _navegarAConfiguracion,
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© ${DateTime.now().year} Suray',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildDrawerItem({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    Widget? trailing,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      trailing: trailing ?? (badge != null
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor ?? theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          badge,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      )
          : null),
      onTap: enabled
          ? () {
        Navigator.pop(context);
        onTap?.call();
      }
          : null,
      enabled: enabled,
    );
  }

  Widget _buildWindowsLayout(ThemeData theme) {
    return Row(
      children: [
        _buildWindowsSidebar(theme),

        Expanded(
          child: Container(
            color: theme.colorScheme.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWindowsHeader(theme),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildUltimasActualizaciones(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsSidebar(ThemeData theme) {
    return Container(
      width: 280,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mantenimiento Suray',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
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
                _buildSidebarCategory('GESTIÓN DE FLOTA', theme),

                _buildSidebarItem(
                  theme: theme,
                  icon: Icons.directions_bus_filled,
                  title: 'Ver Máquinas',
                  badge: _totalMaquinas > 0 ? '$_totalMaquinas' : null,
                  isSelected: _selectedIndex == 0,
                  onTap: _hayDatosMaquinas ? () {
                    setState(() => _selectedIndex = 0);
                    _navegarAMaquinas();
                  } : null,
                  enabled: _hayDatosMaquinas,
                ),

                _buildSidebarItem(
                  theme: theme,
                  icon: Icons.add_circle_outline,
                  title: 'Agregar Máquina',
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    _editarMaquina();
                  },
                ),

                _buildSidebarItem(
                  theme: theme,
                  icon: Icons.assessment,
                  title: 'Reportes',
                  badge: (_revisionesProximas + _revisionesVencidas) > 0
                      ? '${_revisionesProximas + _revisionesVencidas}'
                      : null,
                  badgeColor: Colors.red,
                  isSelected: _selectedIndex == 2,
                  onTap: _hayDatosMaquinas ? () {
                    setState(() => _selectedIndex = 2);
                    _navegarAGenerarReporte();
                  } : null,
                  enabled: _hayDatosMaquinas,
                ),

                _buildSidebarCategory('EXPORTACIÓN E IMPORTACIÓN', theme),

                _buildSidebarItem(
                  theme: theme,
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
                  theme: theme,
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
                  theme: theme,
                  icon: Icons.upload_file,
                  title: 'Importar Documento',
                  isSelected: _selectedIndex == 5,
                  onTap: () {
                    setState(() => _selectedIndex = 5);
                    _navegarAImportarDocumento();
                  },
                ),

                _buildSidebarItem(
                  theme: theme,
                  icon: Icons.upload_file,
                  title: 'Importar Excel',
                  isSelected: _selectedIndex == 6,
                  onTap: () {
                    setState(() => _selectedIndex = 6);
                    _navegarAImportarExcel();
                  },
                ),

                _buildSidebarCategory('CONFIGURACIÓN', theme),

                _buildSidebarItem(
                  theme: theme,
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
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '© ${DateTime.now().year} Suray',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
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

  Widget _buildSidebarCategory(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    String? shortcut,
    required bool isSelected,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: !enabled
              ? theme.colorScheme.onSurface.withOpacity(0.3)
              : (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.7)),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: !enabled
                ? theme.colorScheme.onSurface.withOpacity(0.3)
                : (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: badge != null
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor ?? theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        )
            : null,
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

  Widget _buildWindowsHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panel de Control',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bienvenido al sistema de gestión de flota de buses',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
            _buildQuickStats(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme) {
    return Row(
      children: [
        _buildStatCard(
          theme: theme,
          icon: Icons.directions_bus,
          title: 'Total de Máquinas',
          value: '$_totalMaquinas',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme: theme,
          icon: Icons.warning,
          title: 'Revisiones Próximas',
          value: '$_revisionesProximas',
          color: Colors.orange,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme: theme,
          icon: Icons.dangerous,
          title: 'Revisiones Vencidas',
          value: '$_revisionesVencidas',
          color: Colors.red,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme: theme,
          icon: Icons.check_circle,
          title: 'Máquinas Activas',
          value: '$_maquinasActivas',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
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
          borderRadius: BorderRadius.circular(12),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
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
  Widget _buildUltimasActualizaciones(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Panorama General',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_ultimaActualizacion != null)
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(_ultimaActualizacion!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Gráfico de estado y últimas actualizaciones
        Expanded(
          child: _ultimasMaquinasActualizadas.isEmpty
              ? _buildEmptyState(theme)
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gráficos
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de la Flota',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Distribución actual de máquinas por estado',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Expanded(
                        child: Row(
                          children: [
                            // Gráfico circular
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: _maquinasActivas.toDouble(),
                                      title: _maquinasActivas > 0 ? 'Activas' : '',
                                      color: Colors.green,
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: _maquinasMantenimiento.toDouble(),
                                      title: _maquinasMantenimiento > 0 ? 'Mantenimiento' : '',
                                      color: Colors.orange,
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: _maquinasFueraServicio.toDouble(),
                                      title: _maquinasFueraServicio > 0 ? 'Fuera' : '',
                                      color: Colors.red,
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),

                            // Leyenda
                            const SizedBox(width: 24),

                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLegendItem(
                                  theme: theme,
                                  color: Colors.green,
                                  title: 'Máquinas Activas',
                                  value: '$_maquinasActivas',
                                ),
                                const SizedBox(height: 16),
                                _buildLegendItem(
                                  theme: theme,
                                  color: Colors.orange,
                                  title: 'En Mantenimiento',
                                  value: '$_maquinasMantenimiento',
                                ),
                                const SizedBox(height: 16),
                                _buildLegendItem(
                                  theme: theme,
                                  color: Colors.red,
                                  title: 'Fuera de Servicio',
                                  value: '$_maquinasFueraServicio',
                                ),

                                if (_totalMaquinas > 0) ...[
                                  const SizedBox(height: 24),
                                  const Divider(),
                                  const SizedBox(height: 16),

                                  _buildLegendItem(
                                    theme: theme,
                                    color: theme.colorScheme.primary,
                                    title: 'Total de Máquinas',
                                    value: '$_totalMaquinas',
                                    fontSize: 18,
                                    iconSize: 18,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Botones de acción rápida
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _hayDatosMaquinas ? _navegarAMaquinas : null,
                            icon: const Icon(Icons.directions_bus),
                            label: const Text('Ver todas'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(color: theme.colorScheme.primary),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
                            icon: const Icon(Icons.analytics),
                            label: const Text('Análisis detallado'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Últimas actualizaciones
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Últimas Actualizaciones',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _verificarDatos,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Actualizar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Máquinas recientemente añadidas o modificadas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView.separated(
                          itemCount: _ultimasMaquinasActualizadas.length,
                          separatorBuilder: (context, index) => const Divider(height: 32),
                          itemBuilder: (context, index) {
                            final maquina = _ultimasMaquinasActualizadas[index];
                            final List<String> fotos = maquina['fotos'] != null ?
                            List<String>.from(maquina['fotos']) : [];
                            String fechaTexto = '';

                            if (maquina['fechaModificacion'] != null) {
                              try {
                                final fecha = DateTime.parse(maquina['fechaModificacion']);
                                fechaTexto = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
                              } catch (e) {
                                fechaTexto = 'Fecha no disponible';
                              }
                            } else if (maquina['fechaRevisionTecnica'] != null) {
                              try {
                                final fecha = DateTime.parse(maquina['fechaRevisionTecnica']);
                                fechaTexto = DateFormat('dd/MM/yyyy').format(fecha);
                              } catch (e) {
                                fechaTexto = 'Fecha no disponible';
                              }
                            } else {
                              fechaTexto = 'Sin fecha registrada';
                            }

                            return FadeIn(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditMaquinaScreen(
                                        maquinaExistente: maquina,
                                        onSave: (maquinaActualizada) {
                                          _verificarDatos();
                                        },
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Icono o imagen de máquina
                                      if (fotos.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            File(fotos.first),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildMaquinaIcono(maquina, theme);
                                            },
                                          ),
                                        )
                                      else
                                        _buildMaquinaIcono(maquina, theme),

                                      const SizedBox(width: 16),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Placa y Modelo
                                                Text(
                                                  '${maquina['placa']} - ${maquina['modelo']}',
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),

                                                // Estado
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _getEstadoColor(maquina['estado']).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: _getEstadoColor(maquina['estado']),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    maquina['estado'] ?? 'Sin estado',
                                                    style: TextStyle(
                                                      color: _getEstadoColor(maquina['estado']),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),

                                            // ID y capacidad
                                            Text(
                                              'ID: ${maquina['id']} | Capacidad: ${maquina['capacidad'] ?? 0} pasajeros',
                                              style: theme.textTheme.bodyMedium,
                                            ),

                                            const SizedBox(height: 8),

                                            // Fecha Revisión Técnica
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 14,
                                                  color: _getColorEstadoFecha(maquina['fechaRevisionTecnica']),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Revisión: ${_formatearFecha(maquina['fechaRevisionTecnica'])}',
                                                  style: TextStyle(
                                                    color: _getColorEstadoFecha(maquina['fechaRevisionTecnica']),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Modificado: $fechaTexto',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 8),

                                            // Fotos indicador
                                            if (fotos.length > 1)
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.photo_library,
                                                    size: 14,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${fotos.length} fotos adjuntas',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required ThemeData theme,
    required Color color,
    required String title,
    required String value,
    double fontSize = 14,
    double iconSize = 14,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: fontSize,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: fontSize + 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaquinaIcono(Map<String, dynamic> maquina, ThemeData theme) {
    final estado = maquina['estado'] ?? '';
    final Color estadoColor = _getEstadoColor(estado);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: estadoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estadoColor.withOpacity(0.3),
        ),
      ),
      child: Icon(
        Icons.directions_bus,
        color: estadoColor,
        size: 40,
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    if (estado == 'Activo') return Colors.green;
    if (estado == 'En mantenimiento') return Colors.orange;
    if (estado == 'Fuera de servicio') return Colors.red;
    return Colors.grey;
  }

  Color _getColorEstadoFecha(String? fechaIso) {
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay máquinas registradas',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza agregando una nueva máquina a tu flota',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _editarMaquina,
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

  Widget _buildMobileLayout(bool isLandscape, ThemeData theme) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),

          if (_hayDatosMaquinas)
            _buildDashboard(theme),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: isLandscape
                  ? _buildLandscapeGrid(theme)
                  : _buildPortraitGrid(theme),
            ),
          ),

          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
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
                Text(
                  'Mantenimiento Buses Suray',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Sistema de Gestión de Flota',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          badges.Badge(
            showBadge: (_revisionesProximas + _revisionesVencidas) > 0,
            badgeContent: Text(
              '${_revisionesProximas + _revisionesVencidas}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            position: badges.BadgePosition.topEnd(top: -5, end: -5),
            badgeStyle: const badges.BadgeStyle(
              badgeColor: Colors.red,
              padding: EdgeInsets.all(4),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // Implementar pantalla de notificaciones
              },
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

  Widget _buildDashboard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary,
            Color.lerp(theme.colorScheme.primary, Colors.black, 0.3) ??
                theme.colorScheme.primary.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
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
                theme: theme,
              ),
              _buildMobileStatCard(
                title: 'Próximas',
                value: '$_revisionesProximas',
                icon: Icons.warning,
                theme: theme,
              ),
              _buildMobileStatCard(
                title: 'Vencidas',
                value: '$_revisionesVencidas',
                icon: Icons.dangerous,
                theme: theme,
              ),
              _buildMobileStatCard(
                title: 'Activas',
                value: '$_maquinasActivas',
                icon: Icons.check_circle,
                theme: theme,
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
    required ThemeData theme,
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

  Widget _buildPortraitGrid(ThemeData theme) {
    return _hayDatosMaquinas
        ? GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.0,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          theme: theme,
          title: 'Ver Máquinas',
          icon: Icons.directions_bus_filled,
          color: theme.colorScheme.primary,
          description: 'Consulta la información detallada de todas las máquinas',
          onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Editar Máquina',
          icon: Icons.edit_outlined,
          color: Colors.green,
          description: 'Añade o modifica información de las máquinas',
          onTap: _editarMaquina,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Generar Reporte',
          icon: Icons.assessment,
          color: Colors.orange,
          description: 'Visualiza informes y estadísticas',
          onTap: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
          badge: (_revisionesProximas + _revisionesVencidas) > 0
              ? '${_revisionesProximas + _revisionesVencidas}'
              : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Exportar a Excel',
          icon: Icons.table_chart,
          color: const Color(0xFF00897B),
          description: 'Genera un archivo Excel con los datos e imágenes',
          onTap: _hayDatosMaquinas ? _navegarAExportarExcel : null,
        ),
      ],
    )
        : _buildEmptyState(theme);
  }

  Widget _buildLandscapeGrid(ThemeData theme) {
    return _hayDatosMaquinas
        ? GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          theme: theme,
          title: 'Ver Máquinas',
          icon: Icons.directions_bus_filled,
          color: theme.colorScheme.primary,
          description: 'Consulta la información detallada',
          onTap: _hayDatosMaquinas ? _navegarAMaquinas : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Editar Máquina',
          icon: Icons.edit_outlined,
          color: Colors.green,
          description: 'Añade o modifica información',
          onTap: _editarMaquina,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Generar Reporte',
          icon: Icons.assessment,
          color: Colors.orange,
          description: 'Visualiza informes y estadísticas',
          onTap: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
          badge: (_revisionesProximas + _revisionesVencidas) > 0
              ? '${_revisionesProximas + _revisionesVencidas}'
              : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Exportar a Excel',
          icon: Icons.table_chart,
          color: const Color(0xFF00897B),
          description: 'Genera un Excel con datos e imágenes',
          onTap: _hayDatosMaquinas ? _navegarAExportarExcel : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Crear Respaldo',
          icon: Icons.save_alt,
          color: const Color(0xFF7E57C2),
          description: 'Crea un respaldo completo',
          onTap: _hayDatosMaquinas ? _navegarAExportarDocumento : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Importar',
          icon: Icons.file_upload,
          color: const Color(0xFF5C6BC0),
          description: 'Restaura desde un respaldo',
          onTap: _navegarAImportarDocumento,
        ),
      ],
    )
        : _buildEmptyState(theme);
  }

  Widget _buildMenuCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback? onTap,
    String? badge,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDisabled
                  ? Colors.transparent
                  : color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDisabled
                ? theme.colorScheme.outline.withOpacity(0.3)
                : color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            if (badge != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? color.withOpacity(0.05)
                        : color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isDisabled
                        ? color.withOpacity(0.3)
                        : color,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDisabled
                        ? theme.colorScheme.onSurface.withOpacity(0.3)
                        : theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDisabled
                          ? theme.colorScheme.onSurface.withOpacity(0.3)
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ${DateTime.now().year} Suray',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
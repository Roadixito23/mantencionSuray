import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:badges/badges.dart' as badges;
import 'maquina_screen.dart';
import 'edit_maquina_screen.dart';
import 'settings_screen.dart';
import 'generate_excel_screen.dart';
import 'export_document_screen.dart';
import 'import_document_screen.dart';
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

        // Ordenar por fecha de modificación si existe
        maquinasOrdenadas.sort((a, b) {
          if (a['fechaModificacion'] != null && b['fechaModificacion'] != null) {
            try {
              final DateTime fechaA = DateTime.parse(a['fechaModificacion']);
              final DateTime fechaB = DateTime.parse(b['fechaModificacion']);
              return fechaB.compareTo(fechaA);
            } catch (e) {}
          }
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
                vencidas++;
              } else if (diferencia.inDays <= 30) {
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
          _ultimasMaquinasActualizadas = maquinasOrdenadas.take(5).toList();
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
      appBar: useDesktopLayout ? _buildWindowsAppBar(theme, themeProvider) : null,
      drawer: useDesktopLayout ? null : _buildMobileDrawer(theme, themeProvider),
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
      floatingActionButton: _hayDatosMaquinas ? FloatingActionButton(
        onPressed: _editarMaquina,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Agregar Nueva Máquina',
      ) : null,
    );
  }

  PreferredSizeWidget _buildWindowsAppBar(ThemeData theme, ThemeProvider themeProvider) {
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
        // Solo mostrar alertas si hay revisiones próximas o vencidas
        if ((_revisionesProximas + _revisionesVencidas) > 0)
          badges.Badge(
            showBadge: true,
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
              icon: const Icon(Icons.warning),
              tooltip: 'Revisiones pendientes',
              onPressed: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
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

        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMobileDrawer(ThemeData theme, ThemeProvider themeProvider) {
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

          // Navegación principal
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

          const Divider(height: 32),

          // Herramientas de exportación/importación
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
          _buildDrawerItem(
            theme: theme,
            icon: Icons.upload_file,
            title: 'Importar Documento',
            onTap: _navegarAImportarDocumento,
          ),

          const Divider(height: 32),

          // Configuración y tema
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

                _buildSidebarCategory('HERRAMIENTAS', theme),

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

              // Solo mostrar botones relevantes
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
                  if (_hayDatosMaquinas) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _navegarAGenerarReporte,
                      icon: const Icon(Icons.assessment),
                      label: const Text('Ver Reportes'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
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

        Expanded(
          child: _ultimasMaquinasActualizadas.isEmpty
              ? _buildEmptyState(theme)
              : Container(
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

                                          // Patente y Modelo
                                          Text(
                                            '${maquina['patente']} - ${maquina['modelo']}',
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

          // Solo mostrar alertas si existen
          if ((_revisionesProximas + _revisionesVencidas) > 0)
            badges.Badge(
              showBadge: true,
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
                icon: const Icon(Icons.warning),
                onPressed: _hayDatosMaquinas ? _navegarAGenerarReporte : null,
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
          onTap: _navegarAMaquinas,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Generar Reporte',
          icon: Icons.assessment,
          color: Colors.orange,
          description: 'Visualiza informes y estadísticas',
          onTap: _navegarAGenerarReporte,
          badge: (_revisionesProximas + _revisionesVencidas) > 0
              ? '${_revisionesProximas + _revisionesVencidas}'
              : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Exportar Excel',
          icon: Icons.table_chart,
          color: const Color(0xFF00897B),
          description: 'Genera un archivo Excel con los datos',
          onTap: _navegarAExportarExcel,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Crear Respaldo',
          icon: Icons.save_alt,
          color: const Color(0xFF7E57C2),
          description: 'Crea un respaldo completo',
          onTap: _navegarAExportarDocumento,
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
          onTap: _navegarAMaquinas,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Generar Reporte',
          icon: Icons.assessment,
          color: Colors.orange,
          description: 'Visualiza informes y estadísticas',
          onTap: _navegarAGenerarReporte,
          badge: (_revisionesProximas + _revisionesVencidas) > 0
              ? '${_revisionesProximas + _revisionesVencidas}'
              : null,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Exportar Excel',
          icon: Icons.table_chart,
          color: const Color(0xFF00897B),
          description: 'Genera un Excel con datos',
          onTap: _navegarAExportarExcel,
        ),
        _buildMenuCard(
          theme: theme,
          title: 'Crear Respaldo',
          icon: Icons.save_alt,
          color: const Color(0xFF7E57C2),
          description: 'Crea un respaldo completo',
          onTap: _navegarAExportarDocumento,
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
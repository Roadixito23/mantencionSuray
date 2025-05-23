import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class MachineStatusBadge extends StatelessWidget {
  final String status;

  const MachineStatusBadge({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determinar color según el estado
    Color badgeColor;
    IconData badgeIcon;

    switch (status.toLowerCase()) {
      case 'activo':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        break;
      case 'en taller':
        badgeColor = Colors.orange;
        badgeIcon = Icons.build;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class DateStatusIndicator extends StatelessWidget {
  final dynamic fechaValue;
  final bool showIcon;

  const DateStatusIndicator({
    Key? key,
    required this.fechaValue,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (fechaValue == null) {
      return Text(
        'No registrada',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    try {
      DateTime fechaRevision;

      if (fechaValue is Timestamp) {
        fechaRevision = fechaValue.toDate();
      } else if (fechaValue is String) {
        fechaRevision = DateTime.parse(fechaValue);
      } else if (fechaValue is DateTime) {
        fechaRevision = fechaValue;
      } else {
        throw FormatException('Formato de fecha no válido');
      }

      final DateTime ahora = DateTime.now();
      final int diasRestantes = fechaRevision.difference(ahora).inDays;

      // Determinar estado y color
      Color color;
      String mensaje;
      IconData icon;

      if (diasRestantes < 0) {
        // Vencido
        color = Colors.red;
        mensaje = 'Vencido hace ${-diasRestantes} días';
        icon = Icons.warning;
      } else if (diasRestantes <= 30) {
        // Próximo a vencer
        color = Colors.orange;
        mensaje = 'Faltan $diasRestantes días';
        icon = Icons.access_time;
      } else {
        // Normal
        color = Colors.green;
        mensaje = 'Faltan $diasRestantes días';
        icon = Icons.check_circle;
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            mensaje,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } catch (e) {
      return Text(
        'Fecha inválida',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }
}

class MachineCard extends StatelessWidget {
  final Map<String, dynamic> machine;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isSelected;

  const MachineCard({
    Key? key,
    required this.machine,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hayAlerta = _verificarAlerta();
    final Color colorBorde = hayAlerta ? Colors.orange :
    (isSelected ? theme.colorScheme.primary : Colors.transparent);

    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorBorde,
          width: isSelected || hayAlerta ? 2 : 0,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primary.withOpacity(0.05)
          : theme.colorScheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen de la máquina o icono
                  _buildMachineImage(theme),
                  const SizedBox(width: 16),

                  // Información principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              machine['patente'] ?? 'Sin patente',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hayAlerta
                                    ? Colors.orange
                                    : (isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface),
                              ),
                            ),
                            MachineStatusBadge(status: machine['estado'] ?? 'Sin estado'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nro: ${machine['numeroMaquina'] ?? 'No especificado'}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          machine['modelo'] ?? 'Sin modelo',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (machine['vin'] != null && machine['vin'].toString().isNotEmpty)
                          Text(
                            'VIN: ${machine['vin']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        // Mostrar información de Firebase
                        if (machine['docId'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_done, size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  'Sincronizado',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.blue,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de revisión técnica
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getColorEstadoFecha(machine['fechaRevisionTecnica']).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified,
                      size: 20,
                      color: _getColorEstadoFecha(machine['fechaRevisionTecnica']),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revisión Técnica:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatearFecha(machine['fechaRevisionTecnica']),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _getColorEstadoFecha(machine['fechaRevisionTecnica']),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    DateStatusIndicator(fechaValue: machine['fechaRevisionTecnica']),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Información adicional
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    Icons.people,
                    'Capacidad',
                    '${machine['capacidad'] ?? 0} pas.',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    context,
                    Icons.speed,
                    'Kilometraje',
                    '${machine['kilometraje'] ?? 0} km',
                  ),
                  const Spacer(),
                  // Botones de acción
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: 'Editar',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                  ),
                ],
              ),

              // Mostrar elementos de mantenimiento con alertas
              _buildMaintenancePreview(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMachineImage(ThemeData theme) {
    if (machine['imagenMaquina'] != null && File(machine['imagenMaquina']).existsSync()) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(machine['imagenMaquina']),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultIcon(theme);
            },
          ),
        ),
      );
    } else {
      return _buildDefaultIcon(theme);
    }
  }

  Widget _buildDefaultIcon(ThemeData theme) {
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _obtenerColorEstado().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.directions_bus,
        size: 36,
        color: _obtenerColorEstado(),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenancePreview(BuildContext context) {
    final theme = Theme.of(context);
    final List<dynamic> mantenimiento = machine['mantenimiento'] ?? [];

    if (mantenimiento.isEmpty) {
      return const SizedBox();
    }

    // Contar elementos que requieren atención
    int elementosConAlerta = 0;
    for (var elemento in mantenimiento) {
      if (elemento['fecha'] != null && elemento['tieneFecha'] == true) {
        try {
          DateTime fecha;

          if (elemento['fecha'] is Timestamp) {
            fecha = (elemento['fecha'] as Timestamp).toDate();
          } else if (elemento['fecha'] is String) {
            fecha = DateTime.parse(elemento['fecha']);
          } else if (elemento['fecha'] is DateTime) {
            fecha = elemento['fecha'];
          } else {
            continue;
          }

          final DateTime ahora = DateTime.now();
          final int diasRestantes = fecha.difference(ahora).inDays;

          if (diasRestantes <= 30) {
            elementosConAlerta++;
          }
        } catch (e) {
          // Ignorar fechas inválidas
        }
      }
    }

    if (elementosConAlerta == 0) {
      return const SizedBox();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(color: theme.dividerColor),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.warning,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              '$elementosConAlerta elemento(s) de mantenimiento requieren atención',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _obtenerColorEstado() {
    final estado = machine['estado'] ?? '';

    if (estado == 'Activo') {
      return Colors.green;
    } else if (estado == 'En Taller') {
      return Colors.orange;
    } else if (estado == 'Fuera de Servicio') {
      return Colors.red;
    }

    return Colors.grey;
  }

  bool _verificarAlerta() {
    // Verificar revisión técnica
    if (machine['fechaRevisionTecnica'] != null) {
      try {
        DateTime fechaRevision;

        if (machine['fechaRevisionTecnica'] is Timestamp) {
          fechaRevision = (machine['fechaRevisionTecnica'] as Timestamp).toDate();
        } else if (machine['fechaRevisionTecnica'] is String) {
          fechaRevision = DateTime.parse(machine['fechaRevisionTecnica']);
        } else if (machine['fechaRevisionTecnica'] is DateTime) {
          fechaRevision = machine['fechaRevisionTecnica'];
        } else {
          return false;
        }

        final DateTime ahora = DateTime.now();
        final int diasRestantes = fechaRevision.difference(ahora).inDays;

        if (diasRestantes <= 30) {
          return true;
        }
      } catch (e) {
        // Ignorar fechas inválidas
      }
    }

    // Verificar elementos de mantenimiento
    final List<dynamic> mantenimiento = machine['mantenimiento'] ?? [];
    for (var elemento in mantenimiento) {
      if (elemento['fecha'] != null && elemento['tieneFecha'] == true) {
        try {
          DateTime fecha;

          if (elemento['fecha'] is Timestamp) {
            fecha = (elemento['fecha'] as Timestamp).toDate();
          } else if (elemento['fecha'] is String) {
            fecha = DateTime.parse(elemento['fecha']);
          } else if (elemento['fecha'] is DateTime) {
            fecha = elemento['fecha'];
          } else {
            continue;
          }

          final DateTime ahora = DateTime.now();
          final int diasRestantes = fecha.difference(ahora).inDays;

          if (diasRestantes <= 30) {
            return true;
          }
        } catch (e) {
          // Ignorar fechas inválidas
        }
      }
    }

    return false;
  }

  Color _getColorEstadoFecha(dynamic fechaValue) {
    if (fechaValue == null) {
      return Colors.grey;
    }

    try {
      DateTime fecha;

      if (fechaValue is Timestamp) {
        fecha = fechaValue.toDate();
      } else if (fechaValue is String) {
        fecha = DateTime.parse(fechaValue);
      } else if (fechaValue is DateTime) {
        fecha = fechaValue;
      } else {
        return Colors.grey;
      }

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

  String _formatearFecha(dynamic fechaValue) {
    if (fechaValue == null) {
      return 'No registrada';
    }

    try {
      DateTime fecha;

      if (fechaValue is Timestamp) {
        fecha = fechaValue.toDate();
      } else if (fechaValue is String) {
        fecha = DateTime.parse(fechaValue);
      } else if (fechaValue is DateTime) {
        fecha = fechaValue;
      } else {
        return 'Fecha inválida';
      }

      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}
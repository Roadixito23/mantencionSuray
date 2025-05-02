import 'package:flutter/material.dart';
import 'dart:io';

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
  final String? fechaIso;
  final bool showIcon;

  const DateStatusIndicator({
    Key? key,
    required this.fechaIso,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (fechaIso == null) {
      return Text(
        'No registrada',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    try {
      final DateTime fechaRevision = DateTime.parse(fechaIso!);
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
                  // Icono y estado
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _obtenerColorEstado().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      size: 28,
                      color: _obtenerColorEstado(),
                    ),
                  ),
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
                              machine['placa'] ?? 'Sin placa',
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
                          machine['modelo'] ?? 'Sin modelo',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          'ID: ${machine['id'] ?? 'No especificado'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                      Icons.safety_check,
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
                    DateStatusIndicator(fechaIso: machine['fechaRevisionTecnica']),
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

              // Fotos en miniatura (si hay)
              _buildPhotoPreview(context),
            ],
          ),
        ),
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

  Widget _buildPhotoPreview(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> fotos = machine['fotos'] != null ?
    List<String>.from(machine['fotos']) : [];

    if (fotos.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: theme.dividerColor),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.photo_library,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Fotos adjuntas (${fotos.length})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Image.file(
                      File(fotos[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _obtenerColorEstado() {
    final estado = machine['estado'] ?? '';

    if (estado == 'Activo') {
      return Colors.green;
    } else if (estado == 'En mantenimiento') {
      return Colors.orange;
    } else if (estado == 'Fuera de servicio') {
      return Colors.red;
    }

    return Colors.grey;
  }

  bool _verificarAlerta() {
    if (machine['fechaRevisionTecnica'] == null) {
      return false;
    }

    try {
      final DateTime fechaRevision = DateTime.parse(machine['fechaRevisionTecnica']);
      final DateTime ahora = DateTime.now();
      final int diasRestantes = fechaRevision.difference(ahora).inDays;

      // Alerta si faltan 30 días o menos, o ya está vencido
      return diasRestantes <= 30;
    } catch (e) {
      return false;
    }
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
}
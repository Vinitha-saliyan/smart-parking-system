import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/data/models/parking_area_model.dart';
import 'package:smart_parking_user/data/models/parking_slot_model.dart';
import 'package:smart_parking_user/data/models/reservation_model.dart';
import 'package:smart_parking_user/domain/providers/parking_provider.dart';
import 'package:smart_parking_user/domain/providers/reservation_provider.dart';
import 'package:smart_parking_user/domain/providers/websocket_provider.dart';
import 'package:smart_parking_user/ui/parking_map/widgets/floor_selector.dart';
import 'package:smart_parking_user/ui/payment/payment_screen.dart';

class ParkingMapScreen extends ConsumerStatefulWidget {
  const ParkingMapScreen({
    super.key,
    this.areaId,
  });

  final String? areaId;

  @override
  ConsumerState<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends ConsumerState<ParkingMapScreen> {
  int _selectedFloor = 1;

  static final RegExp _standardPlate = RegExp(
    r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$',
  );
  static final RegExp _bharatPlate = RegExp(
    r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$',
  );

  String _normalizePlate(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _isValidPlate(String value) {
    return _standardPlate.hasMatch(value) || _bharatPlate.hasMatch(value);
  }

  String _normalizeStatus(String status) {
    return status.split('.').last.toUpperCase();
  }

  ParkingAreaModel? _selectedArea(List<ParkingAreaModel> areas) {
    if (areas.isEmpty) return null;
    if (widget.areaId == null) return areas.first;
    for (final area in areas) {
      if (area.id == widget.areaId) return area;
    }
    return null;
  }

  void _showMessage(
    String message, {
    Color backgroundColor = AppColors.error,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('AppException: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('slot is not available')) {
      return 'That slot was just booked. Select another live slot.';
    }
    if (lower.contains('vehicle number')) return message;
    if (lower.contains('unauthorized') || lower.contains('not authenticated')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (lower.contains('connection') || lower.contains('timeout')) {
      return 'Unable to reach the parking database. Please try again.';
    }
    return message.isEmpty ? 'Unable to reserve this slot.' : message;
  }

  Future<void> _openBookingSheet(
    ParkingSlotModel slot,
    ParkingAreaModel area,
  ) async {
    if (_normalizeStatus(slot.status) != 'VACANT' ||
        slot.slotId == 'W01' || slot.slotId == 'W02') {
      return;
    }
    final vehicleController = TextEditingController();
    String? validationError;
    String? postSheetMessage;
    bool refreshSlotsAfterSheet = false;
    bool openReservationsAfterSheet = false;
    bool isSubmitting = false;

    final reservation = await showModalBottomSheet<ReservationModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> reserve() async {
              if (isSubmitting) return;
              final vehicleNumber = _normalizePlate(vehicleController.text);
              if (!_isValidPlate(vehicleNumber)) {
                setSheetState(() {
                  validationError =
                      'Enter a valid number, for example KA19AB1234';
                });
                return;
              }

              setSheetState(() {
                isSubmitting = true;
                validationError = null;
              });

              try {
                final now = DateTime.now();
                final createdReservation = await ref
                    .read(reservationRepositoryProvider)
                    .createReservation(
                      slot.id,
                      area.id,
                      now,
                      now.add(const Duration(hours: 1)),
                      vehicleNumber,
                    );

                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(createdReservation);
                }
              } catch (error) {
                final message = _friendlyError(error);
                final lowerMessage = message.toLowerCase();
                final slotIsUnavailable = message.startsWith(
                  'That slot was just booked.',
                );

                if (slotIsUnavailable) {
                  refreshSlotsAfterSheet = true;
                  postSheetMessage = message;
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  return;
                }

                if (lowerMessage.contains(
                  'already has an active parking reservation',
                )) {
                  try {
                    final existing = await ref
                        .read(reservationRepositoryProvider)
                        .getActiveReservation();
                    if (existing != null &&
                        _normalizePlate(existing.vehicleNumber ?? '') ==
                            vehicleNumber) {
                      final status = _normalizeStatus(existing.status);
                      if (status == 'PAYMENT_PENDING') {
                        postSheetMessage =
                            'Continuing your existing unpaid reservation.';
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop(existing);
                        }
                        return;
                      }

                      openReservationsAfterSheet = true;
                      postSheetMessage =
                          'This vehicle already has a confirmed parking reservation.';
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      return;
                    }
                  } catch (_) {
                    // Keep the original server message when the recovery lookup
                    // itself cannot be completed.
                  }
                }

                _showMessage(message);
                if (sheetContext.mounted) {
                  setSheetState(() => isSubmitting = false);
                }
              }
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                8,
                22,
                22 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'Reserve slot ${slot.slotId}',
                      style:
                          Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${area.name} · Floor ${slot.floor}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: vehicleController,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 15,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9 -]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Vehicle number plate',
                        hintText: 'KA19AB1234',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        errorText: validationError,
                        errorMaxLines: 2,
                        helperText:
                            'The entry camera must scan this same number.',
                        helperMaxLines: 2,
                      ),
                      onSubmitted: (_) => reserve(),
                      onChanged: (_) {
                        if (validationError != null) {
                          setSheetState(() => validationError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '₹10 optional advance · Entry allowed for 30 minutes · only verified advance is deducted',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSubmitting ? null : reserve,
                        icon: isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_clock_outlined),
                        label: Text(
                          isSubmitting
                              ? 'Reserving…'
                              : 'Reserve ${slot.slotId}',
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    // Navigator.pop completes before the bottom-sheet reverse animation has
    // completely detached its inherited-widget dependencies. Wait for that
    // route to leave the tree before disposing its controller, invalidating
    // providers, or pushing the payment route.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    vehicleController.dispose();

    if (!mounted) return;
    if (refreshSlotsAfterSheet) {
      ref.invalidate(parkingSlotsProvider(area.id));
      ref.invalidate(parkingAreasProvider);
    }
    if (postSheetMessage != null) {
      _showMessage(
        postSheetMessage!,
        backgroundColor: reservation == null
            ? AppColors.error
            : AppColors.success,
      );
    }
    if (openReservationsAfterSheet) {
      context.go('/reservations');
      return;
    }
    if (reservation == null) return;

    ref.invalidate(activeReservationProvider);
    ref.invalidate(reservationsListProvider);
    ref.invalidate(parkingSlotsProvider(area.id));
    ref.invalidate(parkingAreasProvider);

    _showMessage(
      'Slot ${slot.slotId} reserved for 30 minutes. Advance payment is optional.',
      backgroundColor: AppColors.success,
    );

    try {
      await context.push(
        '/payment',
        extra: PaymentScreenArgs(
          reservationId: reservation.id,
          amountPaise: ((reservation.totalAmount ?? 10) * 100).round(),
        ),
      );
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(parkingAreasProvider);
    return areas.when(
      loading: () => Scaffold(
        appBar: _appBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: _appBar(),
        body: _LoadError(
          message: 'Unable to load live parking areas.',
          onRetry: () => ref.invalidate(parkingAreasProvider),
        ),
      ),
      data: (items) {
        final area = _selectedArea(items);
        if (area == null) {
          return Scaffold(
            appBar: _appBar(),
            body: const Center(child: Text('No parking area is available.')),
          );
        }
        return _slotPicker(area);
      },
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: const Text('Book a Parking Slot'),
      leading: widget.areaId == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/dashboard'),
            ),
    );
  }

  Widget _slotPicker(ParkingAreaModel area) {
    final slots = ref.watch(parkingSlotsProvider(area.id));

    ref.listen(webSocketProvider(area.id), (previous, next) {
      next.whenData((event) {
        if (event['type'] == 'slot_status_update' ||
            event['type'] == 'gate_event') {
          ref.invalidate(parkingSlotsProvider(area.id));
          ref.invalidate(parkingAreasProvider);
          ref.invalidate(activeReservationProvider);
        }
      });
    });

    return Scaffold(
      appBar: _appBar(),
      body: slots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LoadError(
          message: 'Unable to load real-time slot data.',
          onRetry: () => ref.invalidate(parkingSlotsProvider(area.id)),
        ),
        data: (items) {
          final totalFloors = area.totalFloors > 0 ? area.totalFloors : 1;
          final floor = _selectedFloor.clamp(1, totalFloors).toInt();
          final floorSlots = items
              .where(
                (slot) => slot.floor == floor,
              )
              .toList()
            ..sort((a, b) => a.slotId.compareTo(b.slotId));
          final freeCount = floorSlots.where((slot) =>
              _normalizeStatus(slot.status) == 'VACANT' &&
              slot.slotId != 'W01' && slot.slotId != 'W02').length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parkingSlotsProvider(area.id));
              ref.invalidate(parkingAreasProvider);
              await ref.read(parkingSlotsProvider(area.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.cloud_done_outlined,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                area.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Live availability from the database',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$freeCount bookable',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FloorSelector(
                  totalFloors: totalFloors,
                  selectedFloor: floor,
                  onFloorSelected: (value) {
                    setState(() => _selectedFloor = value);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select an available slot number',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Green: available · Yellow: reserved · Red: occupied. '
                  'Reserved and occupied slots cannot be booked.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (floorSlots.isEmpty)
                  const _NoSlots()
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 700 ? 5 : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 124,
                        ),
                        itemCount: floorSlots.length,
                        itemBuilder: (context, index) {
                          final slot = floorSlots[index];
                          final status = _normalizeStatus(slot.status);
                          final walkIn = slot.slotId == 'W01' || slot.slotId == 'W02';
                          final canBook = status == 'VACANT' && !walkIn;
                          final color = status == 'RESERVED'
                              ? Colors.amber
                              : status == 'OCCUPIED'
                                  ? Colors.red
                                  : status == 'VACANT'
                                      ? AppColors.success
                                      : Colors.grey;
                          final label = status == 'VACANT'
                              ? (walkIn ? 'ADMIN ONLY' : 'AVAILABLE')
                              : status;
                          return Card(
                            color: color.withOpacity(0.16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: color, width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: canBook ? () => _openBookingSheet(slot, area) : null,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      canBook ? Icons.local_parking_rounded : Icons.lock_outline,
                                      color: color,
                                      size: 30,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      slot.slotId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoSlots extends StatelessWidget {
  const _NoSlots();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 18),
        child: Column(
          children: [
            Icon(Icons.event_busy_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No slots are configured on this floor.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

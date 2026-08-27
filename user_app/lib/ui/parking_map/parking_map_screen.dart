import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/shimmer_loading.dart';
import 'package:smart_parking_user/data/models/parking_area_model.dart';
import 'package:smart_parking_user/data/models/parking_slot_model.dart';
import 'package:smart_parking_user/domain/models/parking_slot.dart';
import 'package:smart_parking_user/domain/providers/parking_provider.dart';
import 'package:smart_parking_user/domain/providers/reservation_provider.dart';
import 'package:smart_parking_user/domain/providers/websocket_provider.dart';
import 'package:smart_parking_user/ui/parking_map/widgets/floor_selector.dart';
import 'package:smart_parking_user/ui/parking_map/widgets/legend_bar.dart';
import 'package:smart_parking_user/ui/parking_map/widgets/parking_slot_widget.dart';
import 'package:smart_parking_user/ui/parking_map/widgets/slot_detail_sheet.dart';
import 'package:smart_parking_user/ui/payment/payment_screen.dart';

class ParkingMapScreen extends ConsumerStatefulWidget {
  final String? areaId;

  const ParkingMapScreen({
    super.key,
    this.areaId,
  });

  @override
  ConsumerState<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends ConsumerState<ParkingMapScreen> {
  int _selectedFloor = 1;
  bool _isReserving = false;

  String _normalizeStatus(String status) {
    return status.split('.').last.toUpperCase();
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('not authenticated') ||
        message.contains('unauthorized')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (message.contains('cannot reach') ||
        message.contains('connection') ||
        message.contains('timeout')) {
      return 'Unable to connect to parking services. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  ParkingAreaModel? _findSelectedArea(
    List<ParkingAreaModel> areas,
  ) {
    if (areas.isEmpty) {
      return null;
    }

    // When opened from the bottom navigation, use the first area.
    if (widget.areaId == null) {
      return areas.first;
    }

    for (final area in areas) {
      if (area.id == widget.areaId) {
        return area;
      }
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

  void _showSlotDetails(
    ParkingSlotModel slot,
    ParkingAreaModel area,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SlotDetailSheet(
              slot: slot,
              areaName: area.name,
              hourlyRate: area.hourlyRate,
              currency: area.currency,
              isReserving: _isReserving,
              onReserve: () async {
                if (_isReserving) {
                  return;
                }

                if (_normalizeStatus(slot.status) != 'VACANT') {
                  _showMessage(
                    'This parking slot is no longer available.',
                  );
                  return;
                }

                if (mounted) {
                  setState(() {
                    _isReserving = true;
                  });
                }

                if (bottomSheetContext.mounted) {
                  setModalState(() {});
                }

                try {
                  final repository = ref.read(
                    reservationRepositoryProvider,
                  );

                  final startTime = DateTime.now();
                  final endTime = startTime.add(
                    const Duration(hours: 1),
                  );

                  final reservation = await repository.createReservation(
                    slot.id,
                    area.id,
                    startTime,
                    endTime,
                  );

                  if (!mounted) {
                    return;
                  }

                  // Refresh all data affected by the reservation.
                  ref.invalidate(activeReservationProvider);
                  ref.invalidate(reservationsListProvider);
                  ref.invalidate(
                    parkingSlotsProvider(area.id),
                  );
                  ref.invalidate(parkingAreasProvider);

                  if (bottomSheetContext.mounted) {
                    Navigator.of(bottomSheetContext).pop();
                  }

                  if (!mounted) {
                    return;
                  }

                  _showMessage(
                    'Slot held. Pay the ₹10 advance within 30 minutes.',
                    backgroundColor: AppColors.success,
                  );

                  await context.push(
                    '/payment',
                    extra: PaymentScreenArgs(
                      reservationId: reservation.id,
                      amountPaise:
                          ((reservation.totalAmount ?? 10) * 100).round(),
                      currency: 'INR',
                    ),
                  );
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  _showMessage(_friendlyError(error));
                } finally {
                  if (mounted) {
                    setState(() {
                      _isReserving = false;
                    });
                  }

                  if (bottomSheetContext.mounted) {
                    setModalState(() {});
                  }
                }
              },
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted && _isReserving) {
        setState(() {
          _isReserving = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(parkingAreasProvider);

    return areasAsync.when(
      data: (areas) {
        final selectedArea = _findSelectedArea(areas);

        if (selectedArea == null) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: Center(
              child: Text(
                areas.isEmpty
                    ? 'No parking areas available'
                    : 'Parking area not found',
              ),
            ),
          );
        }

        return _buildMap(selectedArea);
      },
      loading: () {
        return Scaffold(
          appBar: _buildAppBar(),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unable to load parking areas.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(parkingAreasProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Choose a Parking Slot'),
      leading: widget.areaId != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
            )
          : null,
    );
  }

  Widget _buildMap(ParkingAreaModel area) {
    final slotsAsync = ref.watch(
      parkingSlotsProvider(area.id),
    );

    final webSocketAsync = ref.watch(
      webSocketProvider(area.id),
    );

    final totalFloors = area.totalFloors > 0 ? area.totalFloors : 1;

    final currentFloor = _selectedFloor.clamp(1, totalFloors).toInt();

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${area.availableSlots} slots available',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '₹10 advance',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FloorSelector(
            totalFloors: totalFloors,
            selectedFloor: currentFloor,
            onFloorSelected: (floor) {
              setState(() {
                _selectedFloor = floor;
              });
            },
          ),
          const LegendBar(),
          const SizedBox(height: 6),
          Expanded(
            child: slotsAsync.when(
              data: (slots) {
                final floorSlots = slots
                    .where(
                      (slot) => slot.floor == currentFloor,
                    )
                    .toList();

                if (floorSlots.isEmpty) {
                  return Center(
                    child: Text(
                      'No parking slots available on '
                      'floor $currentFloor',
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: floorSlots.length,
                  itemBuilder: (context, index) {
                    final slot = floorSlots[index];

                    var currentStatus = _normalizeStatus(slot.status);

                    webSocketAsync.whenData((data) {
                      final eventSlotId = data['slot_id']?.toString();

                      final isSameSlot =
                          eventSlotId == slot.id || eventSlotId == slot.slotId;

                      if (isSameSlot && data['status'] != null) {
                        currentStatus = _normalizeStatus(
                          data['status'].toString(),
                        );
                      }
                    });

                    return ParkingSlotWidget(
                      slotId: slot.slotId,
                      status: DomainSlotStatus.fromString(
                        currentStatus,
                      ),
                      type: DomainSlotType.fromString(
                        slot.slotType,
                      ),
                      onTap: () {
                        if (currentStatus != 'VACANT') {
                          _showMessage(
                            'Only vacant parking slots '
                            'can be booked.',
                          );
                          return;
                        }

                        _showSlotDetails(slot, area);
                      },
                    );
                  },
                );
              },
              loading: () {
                return ShimmerLoading.grid(
                  crossAxisCount: 4,
                  childAspectRatio: 0.7,
                );
              },
              error: (error, stackTrace) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Unable to load parking slots.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(
                              parkingSlotsProvider(area.id),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

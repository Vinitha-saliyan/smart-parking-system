import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_parking_user/core/constants/app_colors.dart';
import 'package:smart_parking_user/core/widgets/shimmer_loading.dart';
import 'package:smart_parking_user/data/models/parking_area_model.dart';
import 'package:smart_parking_user/data/models/parking_slot_model.dart';
import 'package:smart_parking_user/domain/providers/parking_provider.dart';
import 'package:smart_parking_user/ui/dashboard/widgets/nearby_parking_card.dart';
import 'package:smart_parking_user/ui/search/widgets/filter_chips.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Available',
    'VIP',
    'EV Charging',
    'Accessible',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _requiredSlotType() {
    switch (_selectedFilter) {
      case 'VIP':
        return 'VIP';
      case 'EV Charging':
        return 'EV';
      case 'Accessible':
        return 'DISABLED';
      default:
        return null;
    }
  }

  String _normalizeValue(String value) {
    return value.split('.').last.toUpperCase();
  }

  bool _hasAvailableSlotOfType(
    AsyncValue<List<ParkingSlotModel>>? slotsAsync,
    String requiredType,
  ) {
    if (slotsAsync == null) {
      return false;
    }

    return slotsAsync.maybeWhen(
      data: (slots) {
        return slots.any((slot) {
          final slotType = _normalizeValue(slot.slotType);
          final slotStatus = _normalizeValue(slot.status);

          return slotType == requiredType && slotStatus == 'VACANT';
        });
      },
      orElse: () => false,
    );
  }

  bool _matchesSearch(
    ParkingAreaModel area,
    String query,
  ) {
    if (query.isEmpty) {
      return true;
    }

    return area.name.toLowerCase().contains(query) ||
        area.address.toLowerCase().contains(query);
  }

  Future<void> _refreshAreas(
    List<ParkingAreaModel> areas,
  ) async {
    ref.invalidate(parkingAreasProvider);

    for (final area in areas) {
      ref.invalidate(parkingSlotsProvider(area.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(parkingAreasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Parking'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search destinations, areas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ).animate().slideY(begin: -0.1, end: 0).fadeIn(),
          FilterChips(
            options: _filters,
            selectedOption: _selectedFilter,
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 20),
          Expanded(
            child: areasAsync.when(
              data: (areas) {
                final requiredType = _requiredSlotType();

                final slotStates =
                    <String, AsyncValue<List<ParkingSlotModel>>>{};

                // Slot data is loaded only for filters that require it.
                if (requiredType != null) {
                  for (final area in areas) {
                    slotStates[area.id] = ref.watch(
                      parkingSlotsProvider(area.id),
                    );
                  }
                }

                final isLoadingSlots = requiredType != null &&
                    slotStates.values.any(
                      (state) => state.isLoading,
                    );

                if (isLoadingSlots) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child: ShimmerLoading.card(
                          height: 230,
                        ),
                      );
                    },
                  );
                }

                final query = _searchController.text.trim().toLowerCase();

                final filteredAreas = areas.where((area) {
                  if (!_matchesSearch(area, query)) {
                    return false;
                  }

                  if (_selectedFilter == 'Available') {
                    return area.availableSlots > 0;
                  }

                  if (requiredType != null) {
                    return _hasAvailableSlotOfType(
                      slotStates[area.id],
                      requiredType,
                    );
                  }

                  return true;
                }).toList();

                if (filteredAreas.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => _refreshAreas(areas),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(
                          child: Text(
                            'No parking areas found.',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _refreshAreas(areas),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    itemCount: filteredAreas.length,
                    itemBuilder: (context, index) {
                      final area = filteredAreas[index];

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: NearbyParkingCard(
                            area: area,
                            onTap: () {
                              // Switches correctly from the Search
                              // branch to the Parking Map branch.
                              context.go(
                                '/parking-map/${area.id}',
                              );
                            },
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(
                              milliseconds: 50 * index,
                            ),
                          )
                          .slideX(begin: 0.1, end: 0);
                    },
                  ),
                );
              },
              loading: () {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 16,
                      ),
                      child: ShimmerLoading.card(
                        height: 230,
                      ),
                    );
                  },
                );
              },
              error: (_, __) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Unable to load parking areas. Check the connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(
                              parkingAreasProvider,
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

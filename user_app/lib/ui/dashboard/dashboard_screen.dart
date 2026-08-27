import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smart_parking_user/core/utils/extensions.dart';
import 'package:smart_parking_user/core/widgets/shimmer_loading.dart';
import 'package:smart_parking_user/domain/providers/auth_provider.dart';
import 'package:smart_parking_user/domain/providers/parking_provider.dart';
import 'package:smart_parking_user/domain/providers/reservation_provider.dart';
import 'package:smart_parking_user/ui/dashboard/widgets/active_reservation_card.dart';
import 'package:smart_parking_user/ui/dashboard/widgets/availability_card.dart';
import 'package:smart_parking_user/ui/dashboard/widgets/nearby_parking_card.dart';
import 'package:smart_parking_user/ui/dashboard/widgets/quick_actions.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(parkingAreasProvider);
    ref.invalidate(activeReservationProvider);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final activeReservationAsync = ref.watch(activeReservationProvider);
    final areasAsync = ref.watch(parkingAreasProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.2),
                      backgroundImage: user?.avatarUrl != null
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? Text(user?.fullName.substring(0, 1).toUpperCase() ??
                              'U')
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        Text(
                          user?.fullName ?? 'User',
                          style: TextStyle(
                            fontSize: 16,
                            color: context.textTheme.titleLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.push('/notifications'),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Active Reservation
                    activeReservationAsync.when(
                      data: (reservation) {
                        if (reservation != null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: ActiveReservationCard(
                              reservation: reservation,
                              onTap: () => context.go('/reservations'),
                            )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.1, end: 0),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: ShimmerLoading.card(height: 100),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // Quick Actions
                    QuickActions(
                      onFindParking: () => context.go('/search'),
                      onMyBookings: () => context.go('/reservations'),
                      onScanQR: () => context.go('/reservations'),
                      onHistory: () => context.go('/profile/history'),
                    )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 32),

                    // Live Availability Overview (mocked for total)
                    Text(
                      'City Overview',
                      style: context.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),

                    areasAsync.when(
                      data: (areas) {
                        int total = 0;
                        int available = 0;
                        for (var area in areas) {
                          total += area.totalSlots;
                          available += area.availableSlots;
                        }
                        return AvailabilityCard(
                          totalSlots: total,
                          availableSlots: available,
                          occupiedSlots: total - available,
                        )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideX(begin: 0.1, end: 0);
                      },
                      loading: () => ShimmerLoading.card(height: 120),
                      error: (_, __) => const Text('Failed to load overview'),
                    ),

                    const SizedBox(height: 32),

                    // Nearby Parking
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nearby Parking',
                          style: context.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.go('/search'),
                          child: const Text('See All'),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 240,
                      child: areasAsync.when(
                        data: (areas) {
                          if (areas.isEmpty)
                            return const Center(
                                child: Text('No parking areas found'));
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: areas.length,
                            itemBuilder: (context, index) {
                              return NearbyParkingCard(
                                area: areas[index],
                                onTap: () => context
                                    .go('/parking-map/${areas[index].id}'),
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(
                                          milliseconds: 500 + (index * 100)))
                                  .slideX(begin: 0.2, end: 0);
                            },
                          );
                        },
                        loading: () => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: ShimmerLoading.card(height: 240),
                          ),
                        ),
                        error: (_, __) =>
                            const Center(child: Text('Error loading areas')),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

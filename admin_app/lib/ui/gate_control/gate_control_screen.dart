import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_parking_admin/core/constants/app_colors.dart';
import 'package:smart_parking_admin/core/widgets/admin_card.dart';
import 'package:smart_parking_admin/data/models/gate_model.dart';
import 'package:smart_parking_admin/domain/providers/admin_provider.dart';

class GateControlScreen extends ConsumerStatefulWidget {
  const GateControlScreen({super.key});

  @override
  ConsumerState<GateControlScreen> createState() => _GateControlScreenState();
}

class _GateControlScreenState extends ConsumerState<GateControlScreen> {
  Timer? _statusTimer;
  Timer? _previewTimer;
  GateStatusModel? _status;
  List<GateEventModel> _events = const [];
  List<WalkInSlotModel> _walkInSlots = const [];
  Uint8List? _preview;
  String _mode = 'ENTRY';
  String? _areaId;
  String? _error;
  bool _busy = false;
  bool _polling = false;
  bool _loadingPreview = false;
  String? _selectedWalkInSlotId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollStatus(),
    );
    _previewTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _pollPreview(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _previewTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    try {
      final areas = await ref.read(parkingAreasProvider.future);
      if (!mounted) return;
      if (_areaId == null && areas.isNotEmpty) {
        _areaId = areas.first.id;
      }
      await _pollStatus();
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    }
  }

  Future<void> _pollStatus() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final repository = ref.read(adminRepositoryProvider);
      final areaId = _areaId;
      final results = await Future.wait<dynamic>([
        repository.getGateStatus(),
        repository.getGateEvents(),
        if (areaId == null)
          Future.value(<WalkInSlotModel>[])
        else
          repository.getWalkInSlots(areaId),
      ]);
      if (!mounted) return;
      final status = results[0] as GateStatusModel;
      final walkInSlots = results[2] as List<WalkInSlotModel>;
      final vacantSlots = walkInSlots.where((slot) => slot.isVacant).toList();
      final selectedStillVacant = vacantSlots.any(
        (slot) => slot.id == _selectedWalkInSlotId,
      );
      setState(() {
        _status = status;
        _events = results[1] as List<GateEventModel>;
        _walkInSlots = walkInSlots;
        if (!selectedStillVacant) {
          _selectedWalkInSlotId =
              vacantSlots.isEmpty ? null : vacantSlots.first.id;
        }
        _mode = status.mode;
        if (status.cameraRunning && status.areaId != null) {
          _areaId = status.areaId;
        }
        _error = status.error;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollPreview() async {
    if (_loadingPreview || _status?.cameraRunning != true) return;
    _loadingPreview = true;
    try {
      final bytes = await ref.read(adminRepositoryProvider).getGateSnapshot();
      if (mounted && bytes != null) setState(() => _preview = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      _loadingPreview = false;
    }
  }

  Future<void> _startCamera() async {
    final areaId = _areaId;
    if (areaId == null) {
      setState(() => _error = 'Select a parking area first.');
      return;
    }
    await _runAction(
      () => ref.read(adminRepositoryProvider).startGateCamera(
            mode: _mode,
            areaId: areaId,
          ),
    );
  }

  Future<void> _stopCamera() async {
    await _runAction(
      () => ref.read(adminRepositoryProvider).stopGateCamera(),
    );
    if (mounted) setState(() => _preview = null);
  }

  Future<void> _selectMode(String mode) async {
    final areaId = _areaId;
    setState(() {
      _mode = mode;
      _error = null;
    });
    if (areaId == null || _status?.cameraRunning != true) return;
    await _runAction(
      () => ref.read(adminRepositoryProvider).setGateMode(
            mode: mode,
            areaId: areaId,
          ),
    );
  }

  Future<void> _admitWalkIn() async {
    final areaId = _areaId;
    final slotId = _selectedWalkInSlotId;
    final plate = _status?.lastVehicleNumber;
    if (areaId == null || slotId == null || plate == null) {
      setState(() {
        _error = 'Scan the walk-in plate and select vacant W01 or W02.';
      });
      return;
    }
    await _runAction(
      () => ref.read(adminRepositoryProvider).admitWalkIn(
            areaId: areaId,
            slotId: slotId,
            vehicleNumber: plate,
          ),
    );
  }

  Future<void> _recordWalkInPayment(String method) async {
    final reservationId = _status?.reservationId;
    if (reservationId == null) {
      setState(() => _error = 'Scan the walk-in vehicle in Exit Mode first.');
      return;
    }
    await _runAction(
      () => ref.read(adminRepositoryProvider).recordWalkInPayment(
            reservationId: reservationId,
            method: method,
          ),
    );
  }

  Future<void> _runAction(
    Future<GateStatusModel> Function() action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await action();
      if (!mounted) return;
      setState(() => _status = status);
      await _pollStatus();
    } catch (error) {
      if (mounted) setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(parkingAreasProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _pollStatus,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Number Plate Gate',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Plate-only OCR · optional YOLO vehicle context · simulated gate',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _pollStatus,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],
            AdminCard(
              title: 'Camera Controls',
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: areas.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => const Text(
                        'Parking areas unavailable',
                      ),
                      data: (items) => DropdownButtonFormField<String>(
                        initialValue: items.any((item) => item.id == _areaId)
                            ? _areaId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Parking area',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: [
                          for (final area in items)
                            DropdownMenuItem(
                              value: area.id,
                              child: Text(area.name),
                            ),
                        ],
                        onChanged: _status?.cameraRunning == true
                            ? null
                            : (value) => setState(() => _areaId = value),
                      ),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'ENTRY',
                        label: Text('Entry Mode'),
                        icon: Icon(Icons.login_rounded),
                      ),
                      ButtonSegment(
                        value: 'EXIT',
                        label: Text('Exit Mode'),
                        icon: Icon(Icons.logout_rounded),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _busy
                        ? null
                        : (values) => _selectMode(values.first),
                  ),
                  FilledButton.icon(
                    onPressed: _busy || _status?.cameraRunning == true
                        ? null
                        : _startCamera,
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Start Laptop Camera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _status?.cameraRunning != true
                        ? null
                        : _stopCamera,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop Camera'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _cameraCard()),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: _gateStatusCard()),
                ],
              )
            else ...[
              _cameraCard(),
              const SizedBox(height: 18),
              _gateStatusCard(),
            ],
            if (_mode == 'ENTRY') ...[
              const SizedBox(height: 18),
              _walkInControlsCard(),
            ],
            const SizedBox(height: 18),
            _eventsCard(),
          ],
        ),
      ),
    );
  }

  Widget _cameraCard() {
    return AdminCard(
      title: 'Live Laptop Camera',
      trailing: _StatusPill(
        label: _status?.cameraRunning == true ? 'RUNNING' : 'STOPPED',
        color: _status?.cameraRunning == true
            ? AppColors.success
            : Colors.grey,
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ColoredBox(
            color: const Color(0xFF08101F),
            child: _preview == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_off_outlined,
                          color: Colors.white54,
                          size: 52,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Start the camera to begin real detection',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : Image.memory(
                    _preview!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _gateStatusCard() {
    final state = _status?.gateState ?? 'CLOSED';
    final isOpen = state == 'OPEN';
    final needsPayment = state == 'PAYMENT_REQUIRED';
    final color = isOpen
        ? AppColors.success
        : needsPayment
            ? AppColors.warning
            : AppColors.error;
    return AdminCard(
      title: 'Simulated Gate',
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: color,
                  size: 54,
                ),
                const SizedBox(height: 9),
                Text(
                  state.replaceAll('_', ' '),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'OCR reading',
            value: _status?.lastRawVehicleNumber ?? 'Waiting',
          ),
          if (_status?.lastVehicleNumber != null &&
              _status?.lastVehicleNumber != _status?.lastRawVehicleNumber) ...[
            const Divider(height: 24),
            _InfoRow(
              label: 'Matched booking',
              value: _status!.lastVehicleNumber!,
            ),
          ],
          if (_status?.ocrConfidence != null) ...[
            const Divider(height: 24),
            _InfoRow(
              label: 'OCR confidence',
              value:
                  '${(_status!.ocrConfidence! * 100).toStringAsFixed(0)}%',
            ),
          ],
          if (_status?.decisionSeconds != null) ...[
            const Divider(height: 24),
            _InfoRow(
              label: 'Decision time',
              value: '${_status!.decisionSeconds!.toStringAsFixed(2)} s',
            ),
          ],
          const Divider(height: 24),
          _InfoRow(
            label: 'Decision',
            value: _status?.lastAuthorized == null
                ? 'No scan yet'
                : _status!.lastAuthorized!
                    ? 'AUTHORIZED'
                    : 'DENIED',
          ),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_status?.message ?? 'Loading gate status…'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: _status?.yoloLoaded == true
                    ? 'YOLO LOADED'
                    : 'YOLO LAZY',
                color: AppColors.info,
              ),
              _StatusPill(
                label: _status?.ocrLoaded == true
                    ? 'OCR LOADED'
                    : 'OCR LAZY',
                color: AppColors.info,
              ),
            ],
          ),
          if (_status?.manualPaymentRequired == true) ...[
            const Divider(height: 30),
            Text(
              'Walk-in amount due: ₹${(_status?.amountDue ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _recordWalkInPayment('CASH'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record Cash'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _recordWalkInPayment('UPI'),
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('Record UPI'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _walkInControlsCard() {
    final plate = _status?.lastVehicleNumber;
    final canAssign = plate != null &&
        _status?.reservationId == null &&
        _selectedWalkInSlotId != null &&
        _status?.cameraRunning == true;
    return AdminCard(
      title: 'Walk-in Parking · W01 / W02',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plate == null
                ? 'Scan a vehicle with no prebooking, then manually select a vacant walk-in slot.'
                : _status?.reservationId == null
                    ? 'Detected $plate. Select the slot to assign.'
                    : '$plate is already linked to ${_status?.slotNumber ?? 'a parking slot'}.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final slot in _walkInSlots)
                ChoiceChip(
                  label: Text('${slot.slotNumber} · ${slot.status}'),
                  selected: slot.id == _selectedWalkInSlotId,
                  onSelected: slot.isVacant && !_busy
                      ? (_) => setState(
                            () => _selectedWalkInSlotId = slot.id,
                          )
                      : null,
                ),
              if (_walkInSlots.isEmpty)
                const Text('W01/W02 are being prepared by the backend.'),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: canAssign && !_busy ? _admitWalkIn : null,
            icon: const Icon(Icons.directions_car_filled_outlined),
            label: const Text('Admit Walk-in and Open Gate'),
          ),
        ],
      ),
    );
  }

  Widget _eventsCard() {
    return AdminCard(
      title: 'Recent Entry / Exit Scans',
      child: _events.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('No real camera scans have been recorded yet.'),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Number Plate')),
                  DataColumn(label: Text('Slot')),
                  DataColumn(label: Text('Result')),
                  DataColumn(label: Text('Confidence')),
                  DataColumn(label: Text('Message')),
                ],
                rows: [
                  for (final event in _events)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            DateFormat('dd MMM, hh:mm:ss a')
                                .format(event.createdAt.toLocal()),
                          ),
                        ),
                        DataCell(Text(event.eventType)),
                        DataCell(
                          Text(
                            event.vehicleNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        DataCell(Text(event.slotNumber ?? '-')),
                        DataCell(
                          _StatusPill(
                            label: event.authorized ? 'AUTHORIZED' : 'DENIED',
                            color: event.authorized
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        DataCell(
                          Text(
                            event.ocrConfidence == null
                                ? '-'
                                : '${(event.ocrConfidence! * 100).toStringAsFixed(0)}%',
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 320,
                            child: Text(event.message),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/trip_data.dart';
import '../../data/services/location_service.dart';
import '../../data/services/trip_service.dart';
import '../../data/services/trip_storage_service.dart';
import '../widgets/speedometer_widget.dart';
import '../widgets/stat_card.dart';
import 'trip_history_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final LocationService _locationService = LocationService();
  final TripService _tripService = TripService();
  final TripStorageService _storageService = TripStorageService();
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<TripData>? _tripDataSubscription;

  bool _isTracking = false;
  TripData _currentTripData = TripData.initial();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      setState(() {
        _errorMessage = 'Location permission required';
      });
    }
  }

  Future<void> _startTracking() async {
    try {
      setState(() {
        _errorMessage = '';
      });

      await _locationService.startTracking();
      _tripService.startTrip();

      _positionSubscription = _locationService.positionStream.listen(
        (position) {
          _tripService.updatePosition(position);
        },
        onError: (error) {
          setState(() {
            _errorMessage = 'GPS Error: $error';
          });
        },
      );

      _tripDataSubscription = _tripService.tripDataStream.listen(
        (tripData) {
          if (mounted) {
            setState(() {
              _currentTripData = tripData;
            });
          }
        },
      );

      setState(() {
        _isTracking = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    await _tripDataSubscription?.cancel();
    await _locationService.stopTracking();
    _tripService.stopTrip();

    // Save trip if it has meaningful data
    if (_currentTripData.duration.inSeconds > 5) {
      await _storageService.saveTrip(_currentTripData);
    }

    setState(() {
      _isTracking = false;
    });
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TripHistoryScreen()),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _tripDataSubscription?.cancel();
    _locationService.dispose();
    _tripService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isTracking
                          ? AppTheme.successGreen
                          : AppTheme.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isTracking ? 'TRACKING' : 'READY',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const Spacer(),
                  if (_isTracking)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDuration(_currentTripData.duration),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                  if (!_isTracking)
                    GestureDetector(
                      onTap: _openHistory,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),

              // Error message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryRed, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded,
                            color: AppTheme.primaryRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                                color: AppTheme.primaryRed, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Speedometer
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: SpeedometerWidget(
                      speed: _currentTripData.currentSpeed,
                      maxSpeed: 240,
                    ),
                  ),
                ),
              ),

              // Statistics Grid
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'AVG Speed',
                      value: _currentTripData.averageSpeed.toStringAsFixed(0),
                      unit: 'km/h',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Max Speed',
                      value: _currentTripData.maxSpeed.toStringAsFixed(0),
                      unit: 'km/h',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Distance',
                      value: _currentTripData.distance.toStringAsFixed(2),
                      unit: 'km',
                      icon: Icons.straighten_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Duration',
                      value: _currentTripData.duration.inMinutes.toString(),
                      unit: 'min',
                      icon: Icons.access_time_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Control Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isTracking ? AppTheme.primaryRed : AppTheme.successGreen,
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isTracking ? 'STOP TRACKING' : 'START TRACKING',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

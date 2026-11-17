import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

/// Pure-Dart logistic regression inference service.
///
/// Loads the trained model weights and StandardScaler parameters from the
/// bundled [model_metadata.json] asset and exposes a synchronous [predict]
/// method that mirrors the sklearn pipeline:
///
///   scaled = (raw - mean) / scale
///   logit  = dot(scaled, weights) + bias
///   prob   = sigmoid(logit)
///
/// This avoids pulling in the native `tflite_flutter` dependency entirely —
/// the .tflite flatbuffer is kept in assets for provenance but inference runs
/// through this lightweight evaluator.
class PhubInferenceService {
  // ── Model parameters (populated by [load]) ───────────────────────
  late final List<String> _featureNames;
  late final List<double> _scalerMean;
  late final List<double> _scalerScale;
  late final List<double> _weights;
  late final double _bias;
  late final double _defaultThreshold;

  bool _loaded = false;

  /// Whether the model has been loaded and is ready for inference.
  bool get isReady => _loaded;

  /// Human-readable feature names in the order the model expects.
  List<String> get featureNames =>
      _loaded ? List.unmodifiable(_featureNames) : const [];

  /// The default decision threshold (typically 0.5).
  double get defaultThreshold => _loaded ? _defaultThreshold : 0.5;

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Loads model parameters from the bundled JSON asset.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(
      'assets/models/model_metadata.json',
    );
    final Map<String, dynamic> meta = json.decode(raw) as Map<String, dynamic>;

    _featureNames = List<String>.from(meta['feature_names'] as List);
    _scalerMean = List<double>.from(
      (meta['scaler_mean'] as List).map((v) => (v as num).toDouble()),
    );
    _scalerScale = List<double>.from(
      (meta['scaler_scale'] as List).map((v) => (v as num).toDouble()),
    );
    _weights = List<double>.from(
      (meta['weights'] as List).map((v) => (v as num).toDouble()),
    );
    _bias = (meta['bias'] as num).toDouble();
    _defaultThreshold = (meta['default_threshold'] as num).toDouble();

    // Sanity-check dimensions.
    assert(_featureNames.length == _weights.length);
    assert(_scalerMean.length == _weights.length);
    assert(_scalerScale.length == _weights.length);

    _loaded = true;
  }

  // ── Inference ────────────────────────────────────────────────────

  /// Returns the raw phubbing probability ∈ [0, 1] for the given feature
  /// vector.
  ///
  /// [rawFeatures] must contain exactly 8 values in the order specified
  /// by [featureNames]:
  ///   0: unlock_freq_1h
  ///   1: app_switch_rate_1h
  ///   2: notif_count_1h
  ///   3: notif_resp_latency_mean_1h
  ///   4: notif_resp_latency_median_1h
  ///   5: hour_of_day
  ///   6: day_of_week
  ///   7: is_weekend (0.0 or 1.0)
  ///
  /// Throws [StateError] if [load] has not been called.
  double predictProbability(List<double> rawFeatures) {
    if (!_loaded) {
      throw StateError(
        'PhubInferenceService.load() must be awaited before calling predict.',
      );
    }
    if (rawFeatures.length != _weights.length) {
      throw ArgumentError(
        'Expected ${_weights.length} features, got ${rawFeatures.length}.',
      );
    }

    // 1. StandardScaler transform: z = (x - mean) / scale
    final scaled = List<double>.generate(_weights.length, (i) {
      final s = _scalerScale[i];
      if (s == 0.0) return 0.0; // avoid division by zero
      return (rawFeatures[i] - _scalerMean[i]) / s;
    });

    // 2. Linear combination: logit = Σ(wᵢ · zᵢ) + bias
    double logit = _bias;
    for (int i = 0; i < _weights.length; i++) {
      logit += _weights[i] * scaled[i];
    }

    // 3. Sigmoid: σ(x) = 1 / (1 + e^(-x))
    return _sigmoid(logit);
  }

  /// Convenience: returns `true` if the predicted probability exceeds the
  /// given [threshold] (defaults to the model's built-in default).
  bool predict(List<double> rawFeatures, {double? threshold}) {
    final prob = predictProbability(rawFeatures);
    return prob >= (threshold ?? _defaultThreshold);
  }

  /// Builds the 8-element raw feature vector from discrete sensor
  /// observations over the last hour, plus the current time.
  ///
  /// This is the bridge between the rolling-window aggregator (Step 2) and
  /// the model. Call [predictProbability] or [predict] with the result.
  static List<double> buildFeatureVector({
    required int unlockCountLastHour,
    required int appSwitchCountLastHour,
    required int notifCountLastHour,
    required double notifRespLatencyMeanSec,
    required double notifRespLatencyMedianSec,
    required DateTime now,
  }) {
    return [
      unlockCountLastHour.toDouble(),       // unlock_freq_1h
      appSwitchCountLastHour.toDouble(),     // app_switch_rate_1h
      notifCountLastHour.toDouble(),         // notif_count_1h
      notifRespLatencyMeanSec,               // notif_resp_latency_mean_1h
      notifRespLatencyMedianSec,             // notif_resp_latency_median_1h
      now.hour.toDouble(),                   // hour_of_day
      now.weekday.toDouble() - 1,            // day_of_week (Mon=0 .. Sun=6)
      (now.weekday >= 6) ? 1.0 : 0.0,       // is_weekend
    ];
  }

  // ── Internals ────────────────────────────────────────────────────

  static double _sigmoid(double x) {
    // Clamp to avoid overflow in exp().
    final clamped = x.clamp(-500.0, 500.0);
    return 1.0 / (1.0 + math.exp(-clamped));
  }
}

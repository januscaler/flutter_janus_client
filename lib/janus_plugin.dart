part of janus_client;

abstract class JanusPlugins {
  static const VIDEO_ROOM = "janus.plugin.videoroom";
  static const AUDIO_BRIDGE = "janus.plugin.audiobridge";
  static const STREAMING = "janus.plugin.streaming";
  static const VIDEO_CALL = "janus.plugin.videocall";
  static const TEXT_ROOM = "janus.plugin.textroom";
  static const ECHO_TEST = "janus.plugin.echotest";
  static const SIP = "janus.plugin.sip";
}

/// Describes which WebRTC statistics bucket should be inspected.
///
/// Use [inbound] for receivers (remote streams flowing in) and [outbound]
/// for senders (local tracks you publish to Janus).
enum RtpStreamDirection { inbound, outbound }

/// Output unit that bitrates can be converted into when formatting results.
enum BitrateUnit { bps, kbps, mbps, gbps }

/// High-level network state derived from bitrate samples.
enum NetworkQuality { excellent, good, poor, veryPoor }

/// Explains how a [NetworkQualitySnapshot] was resolved.
///
/// * [measurement] – derived from a concrete bitrate delta.
/// * [insufficientData] – waiting for the second sample to arrive.
/// * [stale] – samples stopped arriving beyond the configured timeout.
enum NetworkQualityReason { measurement, insufficientData, stale }

/// Signature for functions that turn a [BitrateMeasurement] into display text.
typedef BitrateFormatter = String Function(BitrateMeasurement measurement);

extension _RtpStreamDirectionExt on RtpStreamDirection {
  String get statsType {
    switch (this) {
      case RtpStreamDirection.inbound:
        return 'inbound-rtp';
      case RtpStreamDirection.outbound:
        return 'outbound-rtp';
    }
  }

  String get bytesField {
    switch (this) {
      case RtpStreamDirection.inbound:
        return 'bytesReceived';
      case RtpStreamDirection.outbound:
        return 'bytesSent';
    }
  }
}

extension _BitrateUnitExt on BitrateUnit {
  double get scale {
    switch (this) {
      case BitrateUnit.bps:
        return 1;
      case BitrateUnit.kbps:
        return 1000;
      case BitrateUnit.mbps:
        return 1000000;
      case BitrateUnit.gbps:
        return 1000000000;
    }
  }

  String get label {
    switch (this) {
      case BitrateUnit.bps:
        return 'bps';
      case BitrateUnit.kbps:
        return 'kbps';
      case BitrateUnit.mbps:
        return 'Mbps';
      case BitrateUnit.gbps:
        return 'Gbps';
    }
  }
}

/// Holds a bitrate sample in bits per second together with the sampled time.
class BitrateMeasurement {
  BitrateMeasurement({required this.bitsPerSecond, required this.sampledAt});

  final double bitsPerSecond;
  final DateTime sampledAt;

  /// Converts the stored bitrate into the requested [unit].
  double asUnit(BitrateUnit unit) => bitsPerSecond / unit.scale;

  /// Formats the measurement using [unit]. Supply [suffix] to override the
  /// default unit label (useful when localising strings).
  String format({BitrateUnit unit = BitrateUnit.kbps, int fractionDigits = 0, String? suffix}) {
    final value = asUnit(unit);
    final label = suffix ?? unit.label;
    final formatted = value.toStringAsFixed(fractionDigits);
    return label.isEmpty ? formatted : '$formatted $label';
  }
}

/// Classification thresholds that translate bitrate samples into
/// [NetworkQuality] values.
///
/// The numeric values are expressed in **kilobits per second**. Lower each
/// threshold to make the evaluator more tolerant on constrained networks, or
/// increase them to demand higher quality before reporting "excellent". Ensure
/// [staleAfter] is greater than your sampling interval so transient gaps do not
/// instantly downgrade streams to `stale`.
class NetworkQualityThresholds {
  const NetworkQualityThresholds({
    this.excellentMinimumKbps = 2500,
    this.goodMinimumKbps = 1200,
    this.poorMinimumKbps = 600,
    this.missingDataQuality = NetworkQuality.veryPoor,
    this.staleQuality = NetworkQuality.veryPoor,
    this.staleAfter = const Duration(seconds: 6),
  })  : assert(excellentMinimumKbps >= goodMinimumKbps),
        assert(goodMinimumKbps >= poorMinimumKbps),
        assert(poorMinimumKbps >= 0);

  final double excellentMinimumKbps;
  final double goodMinimumKbps;
  final double poorMinimumKbps;
  final NetworkQuality missingDataQuality;
  final NetworkQuality staleQuality;
  final Duration staleAfter;

  /// Maps a [BitrateMeasurement] to a [NetworkQuality] using the configured thresholds.
  NetworkQuality classify(BitrateMeasurement measurement) {
    final kbps = measurement.asUnit(BitrateUnit.kbps);
    if (kbps >= excellentMinimumKbps) {
      return NetworkQuality.excellent;
    }
    if (kbps >= goodMinimumKbps) {
      return NetworkQuality.good;
    }
    if (kbps >= poorMinimumKbps) {
      return NetworkQuality.poor;
    }
    return NetworkQuality.veryPoor;
  }
}

/// Captures the outcome of a network quality evaluation.
///
/// When [reason] is [NetworkQualityReason.measurement] [measurement] is
/// guaranteed to be non-null. Otherwise, it indicates whether the result is
/// still warming up (`insufficientData`) or the stream went silent (`stale`).
class NetworkQualitySnapshot {
  NetworkQualitySnapshot({
    required this.quality,
    required this.evaluatedAt,
    this.measurement,
    required this.reason,
  });

  final NetworkQuality quality;
  final DateTime evaluatedAt;
  final BitrateMeasurement? measurement;
  final NetworkQualityReason reason;

  /// Convenience flag indicating whether a concrete bitrate sample backs the
  /// reported [quality].
  bool get hasMeasurement => measurement != null;
}

/// Declarative matcher used to locate a specific RTP stats entry.
///
/// When multiple properties are supplied all of them must match. Provide
/// [historyKey] or [historyKeyResolver] to avoid collisions when monitoring
/// multiple tracks with the same mid. Set [fallbackToFirstMatching] to `false`
/// if you prefer returning `null` instead of silently inspecting the first
/// video stream when no explicit match is found.
class RtpStreamQuery {
  const RtpStreamQuery({
    this.mid,
    this.trackId,
    this.ssrc,
    this.kind = 'video',
    this.direction = RtpStreamDirection.inbound,
    this.where,
    this.historyKey,
    this.historyKeyResolver,
    this.fallbackToFirstMatching = true,
  });

  final String? mid;
  final String? trackId;
  final String? ssrc;
  final String? kind;
  final RtpStreamDirection direction;
  final bool Function(dynamic report)? where;
  final String? historyKey;
  final String Function(dynamic report)? historyKeyResolver;
  final bool fallbackToFirstMatching;

  /// Checks whether [report] satisfies all constraints specified on this query.
  bool matches(dynamic report) {
    if (report == null) {
      return false;
    }
    if (report.type != direction.statsType) {
      return false;
    }
    final values = _valuesOf(report);
    if (kind != null && values['kind'] != kind) {
      return false;
    }
    if (mid != null && values['mid'] != mid) {
      return false;
    }
    if (trackId != null && !_matchesTrackId(values, trackId!)) {
      return false;
    }
    if (ssrc != null && _stringOrNull(values['ssrc']) != ssrc) {
      return false;
    }
    if (where != null && where!(report) == false) {
      return false;
    }
    return true;
  }

  /// Returns the key used to store history for bitrate deltas.
  String resolveHistoryKey(dynamic report) {
    if (historyKeyResolver != null) {
      return historyKeyResolver!(report);
    }
    if (historyKey != null) {
      return historyKey!;
    }
    final values = _valuesOf(report);
    final resolvedMid = _stringOrNull(values['mid']);
    final resolvedSsrc = _stringOrNull(values['ssrc']);
    final reportId = _stringOrNull(report.id);
    return mid ?? resolvedMid ?? resolvedSsrc ?? reportId ?? direction.statsType;
  }

  static Map<String, dynamic> _valuesOf(dynamic report) {
    final raw = report.values;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  static bool _matchesTrackId(Map<String, dynamic> values, String expected) {
    final candidates = <String?>[
      _stringOrNull(values['trackIdentifier']),
      _stringOrNull(values['trackId']),
      _stringOrNull(values['track_id']),
    ];
    return candidates.whereType<String>().any((element) => element == expected);
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}

/// Utility wrapper around `RTCPeerConnection.getStats()` that offers
/// incremental bitrate and network quality helpers.
///
/// Instances are lightweight and rely on a caller-provided function to access
/// the current peer connection, which makes the helper resilient to
/// reconnections (e.g. replacing the peer connection during a renegotiation).
class JanusStreamStats {
  JanusStreamStats({
    required RTCPeerConnection? Function() peerConnectionProvider,
    DateTime Function()? clock,
    BitrateFormatter? defaultFormatter,
  })  : _peerConnectionProvider = peerConnectionProvider,
        _clock = clock ?? DateTime.now,
        _defaultFormatter = defaultFormatter;

  final RTCPeerConnection? Function() _peerConnectionProvider;
  final DateTime Function() _clock;
  final BitrateFormatter? _defaultFormatter;
  final Map<String, _RtpSample> _history = <String, _RtpSample>{};

  /// Calculates the bitrate in bits-per-second for the RTP stream matched by
  /// [query]. Consecutive invocations cache the previous sample to compute the
  /// delta; the first call therefore returns `null`.
  Future<BitrateMeasurement?> bitrate({RtpStreamQuery query = const RtpStreamQuery()}) async {
    final connection = _peerConnectionProvider();
    if (connection == null) {
      return null;
    }
    final stats = await connection.getStats();
    final now = _clock();

    final matching = stats.where((report) => query.matches(report)).toList();
    dynamic targetReport = matching.isNotEmpty
        ? matching.first
        : (query.fallbackToFirstMatching ? _firstWhereOrNull(stats, (report) => _directionKindMatch(report, query.direction, query.kind)) : null);

    if (targetReport == null) {
      return null;
    }

    final values = RtpStreamQuery._valuesOf(targetReport);
    final bytesValue = values[query.direction.bytesField];
    final currentBytes = _asPositiveInt(bytesValue);
    if (currentBytes == null) {
      return null;
    }

    final historyKey = query.resolveHistoryKey(targetReport);
    final previous = _history[historyKey];
    _history[historyKey] = _RtpSample(bytes: currentBytes, timestampMillis: now.millisecondsSinceEpoch);

    if (previous == null) {
      return null;
    }

    final bytesDiff = currentBytes - previous.bytes;
    final timeDiffSeconds = (now.millisecondsSinceEpoch - previous.timestampMillis) / 1000.0;
    if (bytesDiff < 0 || timeDiffSeconds <= 0) {
      return null;
    }
    final bitsPerSecond = (bytesDiff * 8) / timeDiffSeconds;
    return BitrateMeasurement(bitsPerSecond: bitsPerSecond, sampledAt: now);
  }

  /// Returns a formatted string representation of [bitrate]. When no
  /// measurement is available the result is `null`.
  Future<String?> bitrateLabel({
    RtpStreamQuery query = const RtpStreamQuery(),
    BitrateUnit unit = BitrateUnit.kbps,
    int fractionDigits = 0,
    BitrateFormatter? formatter,
    String? suffix,
  }) async {
    final measurement = await bitrate(query: query);
    if (measurement == null) {
      return null;
    }
    if (formatter != null) {
      return formatter(measurement);
    }
    if (_defaultFormatter != null) {
      return _defaultFormatter(measurement);
    }
    return measurement.format(unit: unit, fractionDigits: fractionDigits, suffix: suffix);
  }

  /// Evaluates network quality according to [thresholds]. When [previous] is
  /// provided it is used to decide whether missing samples should be treated as
  /// stale (e.g. the publisher disappeared) or still warming up.
  Future<NetworkQualitySnapshot> networkQuality({
    RtpStreamQuery query = const RtpStreamQuery(),
    NetworkQualityThresholds thresholds = const NetworkQualityThresholds(),
    NetworkQualitySnapshot? previous,
  }) async {
    final measurement = await bitrate(query: query);
    final now = _clock();
    if (measurement == null) {
      final reason = previous != null && now.difference(previous.evaluatedAt) >= thresholds.staleAfter ? NetworkQualityReason.stale : NetworkQualityReason.insufficientData;
      final fallbackQuality = reason == NetworkQualityReason.stale ? thresholds.staleQuality : thresholds.missingDataQuality;
      return NetworkQualitySnapshot(quality: fallbackQuality, evaluatedAt: now, measurement: null, reason: reason);
    }
    final quality = thresholds.classify(measurement);
    return NetworkQualitySnapshot(quality: quality, evaluatedAt: now, measurement: measurement, reason: NetworkQualityReason.measurement);
  }

  /// Continuously samples [networkQuality] and emits snapshots over time.
  ///
  /// Use [emitDistinct] to suppress identical consecutive values and
  /// [emitOnListen] to force an immediate evaluation when a listener is added.
  Stream<NetworkQualitySnapshot> watchNetworkQuality({
    RtpStreamQuery query = const RtpStreamQuery(),
    NetworkQualityThresholds thresholds = const NetworkQualityThresholds(),
    Duration sampleInterval = const Duration(seconds: 2),
    bool emitDistinct = true,
    bool emitOnListen = true,
  }) {
    final controller = StreamController<NetworkQualitySnapshot>.broadcast();
    Timer? timer;
    bool sampling = false;
    NetworkQualitySnapshot? lastSnapshot;

    Future<void> sample() async {
      if (sampling) {
        return;
      }
      sampling = true;
      try {
        final snapshot = await networkQuality(query: query, thresholds: thresholds, previous: lastSnapshot);
        final previousSnapshot = lastSnapshot;
        lastSnapshot = snapshot;
        final shouldEmit = !emitDistinct || previousSnapshot == null || previousSnapshot.quality != snapshot.quality || previousSnapshot.reason != snapshot.reason;
        if (shouldEmit && !controller.isClosed) {
          controller.add(snapshot);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        sampling = false;
      }
    }

    controller.onListen = () {
      if (emitOnListen) {
        sample();
      }
      timer ??= Timer.periodic(sampleInterval, (_) => sample());
    };

    controller.onCancel = () {
      if (!controller.hasListener) {
        timer?.cancel();
        timer = null;
      }
    };

    return controller.stream;
  }

  /// Clears cached byte counters so the next bitrate calculation restarts the
  /// measurement window. Provide [historyKey] to reset a single stream.
  void clearHistory({String? historyKey}) {
    if (historyKey != null) {
      _history.remove(historyKey);
    } else {
      _history.clear();
    }
  }

  static dynamic _firstWhereOrNull(Iterable<dynamic> source, bool Function(dynamic) test) {
    for (final element in source) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }

  static bool _directionKindMatch(dynamic report, RtpStreamDirection direction, String? kind) {
    if (report == null || report.type != direction.statsType) {
      return false;
    }
    if (kind == null) {
      return true;
    }
    final values = RtpStreamQuery._valuesOf(report);
    return values['kind'] == kind;
  }

  static int? _asPositiveInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.isFinite ? value.toInt() : null;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse(value.toString());
    return parsed;
  }
}

class _RtpSample {
  _RtpSample({required this.bytes, required this.timestampMillis});

  final int bytes;
  final int timestampMillis;
}

class JanusPlugin {
  void onCreate() {}
  int? handleId;
  late JanusClient _context;
  late JanusTransport? _transport;
  late JanusSession? _session;
  String? plugin;
  bool _initialized = false;

  // internal method which takes care of type of roomId which is normally int but can be string if set in janus config for room
  _handleRoomIdTypeDifference(dynamic payload) {
    if (payload["room"] != null) {
      payload["room"] = _context._stringIds == false ? payload["room"] : payload["room"].toString();
    }
  }

  late Stream<dynamic> _events;
  Stream<EventMessage>? messages;
  Stream<TypedEvent<JanusEvent>>? typedMessages;
  Stream<RTCDataChannelMessage>? data;
  Stream<RTCDataChannelState>? onData;
  Stream<RemoteTrack>? remoteTrack;
  Stream<dynamic>? renegotiationNeeded;
  Stream<MediaStream>? remoteStream;
  Stream<MediaStream?>? localStream;
  StreamController<dynamic>? _renegotiationNeededController;
  StreamController<MediaStream?>? _localStreamController;
  StreamController<RemoteTrack>? _remoteTrackStreamController;
  StreamController<MediaStream>? _remoteStreamController;
  StreamController<dynamic>? _streamController;
  StreamController<EventMessage>? _messagesStreamController;
  StreamController<TypedEvent>? _typedMessagesStreamController;
  StreamController<RTCDataChannelMessage>? _dataStreamController;
  StreamController<RTCDataChannelState>? _onDataStreamController;

  StreamSink? get _typedMessagesSink => _typedMessagesStreamController?.sink;

  int _pollingRetries = 0;
  Timer? _pollingTimer;
  JanusWebRTCHandle? webRTCHandle;
  Map<String, dynamic>? _webRtcConfiguration;

  //temporary variables
  StreamSubscription? _wsStreamSubscription;
  late bool pollingActive;

  /// Exposes WebRTC statistics helpers (bitrate calculations, history, etc.).
  late final JanusStreamStats mediaStats;

  RTCPeerConnection? get peerConnection {
    return webRTCHandle?.peerConnection;
  }

  JanusPlugin({this.handleId, required JanusClient context, required JanusTransport transport, required JanusSession session, this.plugin}) {
    _context = context;
    _session = session;
    _transport = transport;
    mediaStats = JanusStreamStats(peerConnectionProvider: () => webRTCHandle?.peerConnection);
  }

  /// Builds a REST polling URI by preserving the provided base endpoint path
  /// and appending only the `sessionId` segment.
  static Uri buildPollingUri({
    required String baseUrl,
    required int sessionId,
    required Map<String, String> queryParameters,
  }) {
    final baseUri = Uri.parse(baseUrl);
    final mergedQueryParameters = <String, String>{
      ...baseUri.queryParameters,
      ...queryParameters,
    };
    return baseUri.replace(
      pathSegments: <String>[
        ...baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        sessionId.toString(),
      ],
      queryParameters: mergedQueryParameters.isEmpty ? null : mergedQueryParameters,
    );
  }

  /// Initializes or re-initializes the internal WebRTC stack for this plugin.
  ///
  /// The method expects `_webRtcConfiguration` to be populated via [_init] and
  /// creates a fresh `RTCPeerConnection`, wiring renegotiation, track, and ICE
  /// callbacks before storing the resulting [JanusWebRTCHandle].
  Future<void> initializeWebRTCStack() async {
    if (_webRtcConfiguration == null) {
      _context._logger.shout('initializeWebRTCStack:-configuration is null call init before calling me');
      return;
    }
    _context._logger.finest('webRTC stack intialized');
    RTCPeerConnection peerConnection = await createPeerConnection(_webRtcConfiguration!, {});
    peerConnection.onRenegotiationNeeded = () {
      _renegotiationNeededController?.sink.add(true);
    };
    //unified plan webrtc tracks emitter
    _handleUnifiedWebRTCTracksEmitter(peerConnection);
    //send ice candidates to janus server on this specific handle
    _handleIceCandidatesSending(peerConnection);
    webRTCHandle = JanusWebRTCHandle(peerConnection: peerConnection);
  }

  /// Internal helper invoked by [JanusSession.attach] to finish plugin setup.
  ///
  /// The method configures the peer connection, prepares event streams, and
  /// activates transport-specific listeners. External code should rely on
  /// [JanusSession.attach] instead of calling this directly.
  Future<void> _init() async {
    if (!_initialized) {
      _initialized = true;
      _context._logger.info("Plugin Initialized");
      if (webRTCHandle != null) {
        return;
      }
      // initializing WebRTC Handle
      _webRtcConfiguration = {"iceServers": _context._iceServers != null ? _context._iceServers!.map((e) => e.toMap()).toList() : []};
      if (_context._isUnifiedPlan && !_context._usePlanB) {
        _webRtcConfiguration?.putIfAbsent('sdpSemantics', () => 'unified-plan');
      } else {
        _webRtcConfiguration?.putIfAbsent('sdpSemantics', () => 'plan-b');
      }
      _context._logger.fine('peer connection configuration');
      _context._logger.fine(_webRtcConfiguration);
      await initializeWebRTCStack();
      //initialize stream controllers and streams
      _initStreamControllersAndStreams();
      //add Event emitter logic
      _handleEventMessageEmitter();
      this.pollingActive = true;
      // Warning no code should be placed after code below in init function
      // depending on transport setup events and messages for session and plugin
      _handleTransportInitialization();
    } else {
      _context._logger.info("Plugin already Initialized! skipping");
    }
  }

  /// Binds listeners according to the selected transport (REST polling or WS).
  void _handleTransportInitialization() {
    if (_transport is RestJanusTransport) {
      _pollingTimer = Timer.periodic(_context._pollingInterval, (timer) async {
        if (!pollingActive) {
          timer.cancel();
        }
        await _handlePolling();
      });
    } else if (_transport is WebSocketJanusTransport) {
      _wsStreamSubscription = (_transport as WebSocketJanusTransport).stream.listen((event) {
        _streamController!.add(parse(event));
      });
    }
  }

  /// Sets up the broadcast stream controllers used throughout the plugin.
  void _initStreamControllersAndStreams() {
    //source and stream for session level events
    _streamController = StreamController<dynamic>();
    _events = _streamController!.stream.asBroadcastStream();
    //source and stream for localStream
    _localStreamController = StreamController<MediaStream?>();
    localStream = _localStreamController!.stream.asBroadcastStream();
    //source and stream for plugin level events
    _messagesStreamController = StreamController<EventMessage>();
    messages = _messagesStreamController!.stream.asBroadcastStream();

    //typed source and stream for plugin level events
    _typedMessagesStreamController = StreamController<TypedEvent<JanusEvent>>();
    typedMessages = _typedMessagesStreamController!.stream.asBroadcastStream() as Stream<TypedEvent<JanusEvent>>?;

    // remote track for unified plan support
    _remoteTrackStreamController = StreamController<RemoteTrack>();
    remoteTrack = _remoteTrackStreamController!.stream.asBroadcastStream();
    // remote MediaStream plan-b
    _remoteStreamController = StreamController<MediaStream>();
    remoteStream = _remoteStreamController!.stream.asBroadcastStream();

    // data channel stream contoller
    _dataStreamController = StreamController<RTCDataChannelMessage>();
    data = _dataStreamController!.stream.asBroadcastStream();

    // data channel state stream contoller
    _onDataStreamController = StreamController<RTCDataChannelState>();
    onData = _onDataStreamController!.stream.asBroadcastStream();
    // data channel state stream contoller
    _renegotiationNeededController = StreamController<void>();
    renegotiationNeeded = _renegotiationNeededController!.stream.asBroadcastStream();
  }

  /// Registers handlers that translate WebRTC track events to Janus streams.
  void _handleUnifiedWebRTCTracksEmitter(RTCPeerConnection peerConnection) {
    if (_context._isUnifiedPlan && !_context._usePlanB) {
      peerConnection.onTrack = (RTCTrackEvent event) async {
        _context._logger.finest('onTrack called with event');
        _context._logger.fine(event.toString());
        if (event.streams.isEmpty) return;
        // Notify about the new track event

        var mid = event.transceiver != null
            ? event.transceiver?.mid
            : event.receiver != null
                ? event.receiver?.track?.id
                : event.track.id;
        _remoteTrackStreamController?.add(RemoteTrack(track: event.track, mid: mid, flowing: true));
        event.track.onEnded = () async {
          // Notify the application
          if (!_remoteTrackStreamController!.isClosed) _remoteTrackStreamController?.add(RemoteTrack(track: event.track, mid: mid, flowing: false));
        };
        event.track.onMute = () async {
          if (!_remoteTrackStreamController!.isClosed) _remoteTrackStreamController?.add(RemoteTrack(track: event.track, mid: mid, flowing: false));
        };
        event.track.onUnMute = () async {
          if (!_remoteTrackStreamController!.isClosed) _remoteTrackStreamController?.add(RemoteTrack(track: event.track, mid: mid, flowing: true));
        };
      };
    }
    // source for onRemoteStream
    peerConnection.onAddStream = (mediaStream) {
      _remoteStreamController!.sink.add(mediaStream);
    };
  }

  /// Sends gathered ICE candidates to the Janus backend for this handle.
  void _handleIceCandidatesSending(RTCPeerConnection peerConnection) {
    // get ice candidates and send to janus on this plugin handle
    peerConnection.onIceCandidate = (RTCIceCandidate candidate) async {
      Map<String, dynamic>? response;
      if (!plugin!.contains('textroom')) {
        this._context._logger.finest('sending trickle');
        Map<String, dynamic> request = {"janus": "trickle", "candidate": candidate.toMap(), "transaction": getUuid().v4(), ..._context._apiMap, ..._context._tokenMap};
        request["session_id"] = _session!.sessionId;
        request["handle_id"] = handleId;
        //checking and posting using websocket if in available
        if (_transport is RestJanusTransport) {
          RestJanusTransport rest = (_transport as RestJanusTransport);
          response = (await rest.post(request, handleId: handleId)) as Map<String, dynamic>;
        } else if (_transport is WebSocketJanusTransport) {
          WebSocketJanusTransport ws = (_transport as WebSocketJanusTransport);
          response = (await ws.send(request, handleId: handleId)) as Map<String, dynamic>;
        }
        _streamController!.sink.add(response);
      }
    };
  }

  /// Filters session-level events and emits those that match this handle.
  void _handleEventMessageEmitter() {
    //filter and only send events for current handleId
    _events.where((event) {
      Map<String, dynamic> result = event;
      if (result.containsKey('sender')) {
        if ((result['sender'] as int?) == handleId) return true;
        return false;
      } else {
        return false;
      }
    }).listen((event) {
      var jsep = event['jsep'];
      if (jsep != null) {
        _messagesStreamController!.sink.add(EventMessage(event: event, jsep: RTCSessionDescription(jsep['sdp'], jsep['type'])));
      } else {
        _addTrickleCandidate(event);
        _messagesStreamController!.sink.add(EventMessage(event: event, jsep: null));
      }
    });
  }

  /// Applies a single trickle candidate to the active peer connection.
  void _addTrickleCandidate(event) {
    final isTrickleEvent = event['janus'] == 'trickle';
    if (isTrickleEvent) {
      final candidateMap = event['candidate'];
      RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'], candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
      webRTCHandle!.peerConnection!.addCandidate(candidate);
    }
  }

  /// Pulls pending Janus events when REST polling is active.
  _handlePolling() async {
    if (!pollingActive) return;
    if (_session!.sessionId == null) {
      pollingActive = false;
      return;
    }
    try {
      Map<String, String> queryParameters = {};
      queryParameters["rid"] = new DateTime.now().millisecondsSinceEpoch.toString();
      if (_context._maxEvent != null) {
        queryParameters["maxev"] = _context._maxEvent.toString();
      }
      if (_context._token != null) {
        queryParameters["token"] = _context._token!;
      }
      if (_context._apiSecret != null) {
        queryParameters["apisecret"] = _context._apiSecret!;
      }
      final pollingUri = JanusPlugin.buildPollingUri(
        baseUrl: _transport!.url!,
        sessionId: _session!.sessionId!,
        queryParameters: queryParameters,
      );
      var response = (await http.get(pollingUri));
      if (response.statusCode != 200 || response.body.isEmpty) {
        var errorMessage = "polling is failed from janus with error code : ${response.statusCode} , header : ${response.headers}";
        print(response.body);
        print(response.statusCode);
        print(errorMessage);
        _context._logger.severe(errorMessage);
        throw errorMessage;
      }
      var decodedResponse = parse(response.body);
      List<dynamic> json = ((decodedResponse != null && decodedResponse.isNotEmpty)) ? decodedResponse : [];
      json.forEach((element) {
        if (!_streamController!.isClosed) {
          _streamController!.add(element);
        } else {
          pollingActive = false;
          return;
        }
      });
      _pollingRetries = 0;
      return;
    } on HttpException catch (_) {
      _pollingRetries++;
      pollingActive = false;
      if (_pollingRetries > 2) {
        // Did we just lose the server? :-(
        _context._logger.severe("Lost connection to the server (is it down?)");
        return;
      }
    } catch (e) {
      this._context._logger.fine(e);
      pollingActive = false;
      _context._logger.severe("fatal Exception");
      return;
    }
    return;
  }

  /// Checks whether a Janus room identified by [roomId] exists.
  Future<dynamic> exists(int roomId) async {
    var payload = {"request": "exists", "room": roomId};
    return (await this.send(data: payload));
  }

  /// Cancels the REST polling timer if it is currently running.
  void _cancelPollingTimer() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
    }
  }

  /// Disposes the active local stream and, unless [ignoreRemote] is `true`, the
  /// remote stream as well. Optional [video] and [audio] flags allow selectively
  /// stopping tracks before disposing their parent streams.
  Future<void> _disposeMediaStreams({bool ignoreRemote = false, bool video = true, bool audio = true}) async {
    _context._logger.finest('disposing localStream and remoteStream if it already exists');
    if (webRTCHandle?.localStream != null) {
      if (audio) {
        webRTCHandle?.localStream?.getAudioTracks().forEach((element) async {
          _context._logger.finest('stoping localStream => audio track ${element.toString()}');
          await element.stop();
        });
      }
      if (video) {
        webRTCHandle?.localStream?.getVideoTracks().forEach((element) async {
          _context._logger.finest('stoping localStream => video track ${element.toString()}');
          await element.stop();
        });
      }
      if (audio || video) {
        try {
          _context._logger.finest('disposing webRTCHandle?.localStream');
          await webRTCHandle?.localStream?.dispose();
        } catch (e) {
          _context._logger.severe('failed to dispose webRTCHandle?.localStream with error $e');
        }
      }
      webRTCHandle?.localStream = null;
    }
    if (webRTCHandle?.remoteStream != null && !ignoreRemote) {
      webRTCHandle?.remoteStream?.getTracks().forEach((element) async {
        _context._logger.finest('stoping remoteStream => ${element.toString()}');
        await element.stop();
      });
      try {
        _context._logger.finest('disposing webRTCHandle?.remoteStream');
        await webRTCHandle?.remoteStream?.dispose();
      } catch (e) {
        _context._logger.severe('failed to dispose webRTCHandle?.remoteStream with error $e');
      }
      webRTCHandle?.remoteStream = null;
    }
  }

  /// Stops polling and disposes media resources without fully disposing the handle.
  Future<void> hangup({bool disposeStream = true}) async {
    _cancelPollingTimer();
    if (disposeStream) {
      await _disposeMediaStreams();
    }
  }

  void closeStreamControllers() {
    this.pollingActive = false;
    _pollingTimer?.cancel();
    _streamController?.close();
    _remoteStreamController?.close();
    _messagesStreamController?.close();
    _typedMessagesStreamController?.close();
    _localStreamController?.close();
    _remoteTrackStreamController?.close();
    _dataStreamController?.close();
    _onDataStreamController?.close();
    _renegotiationNeededController?.close();
    _wsStreamSubscription?.cancel();
  }

  /// Disposes timers, stream controllers, transports, and media tied to this plugin.
  Future<void> dispose({bool runStopAllTracks = true, bool runStopTransReciever = true}) async {
    closeStreamControllers();
    if (runStopAllTracks) {
      await stopAllTracks(webRTCHandle?.localStream);
    }
    if (runStopTransReciever) {
      (await webRTCHandle?.peerConnection?.getTransceivers())?.forEach((element) async {
        await element.stop();
      });
    }
    await webRTCHandle?.peerConnection?.close();
    await webRTCHandle?.remoteStream?.dispose();
    await webRTCHandle?.localStream?.dispose();
    await webRTCHandle?.peerConnection?.dispose();
    webRTCHandle?.localStream = null;
    webRTCHandle?.remoteStream = null;
    webRTCHandle?.peerConnection = null;
  }

  /// Creates the default data channel when missing for TextRoom/data usage.
  Future<void> initDataChannel({RTCDataChannelInit? rtcDataChannelInit}) async {
    if (webRTCHandle!.peerConnection != null) {
      if (webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel] != null) return;
      if (rtcDataChannelInit == null) {
        rtcDataChannelInit = RTCDataChannelInit();
        rtcDataChannelInit.ordered = true;
        rtcDataChannelInit.protocol = 'janus-protocol';
      }
      webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel] = await webRTCHandle!.peerConnection!.createDataChannel(_context._dataChannelDefaultLabel, rtcDataChannelInit);
      if (webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel] != null) {
        webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel]!.onDataChannelState = (state) {
          if (!_onDataStreamController!.isClosed) {
            _onDataStreamController!.sink.add(state);
          }
        };
        webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel]!.onMessage = (RTCDataChannelMessage message) {
          if (!_dataStreamController!.isClosed) {
            _dataStreamController!.sink.add(message);
          }
        };
      }
    } else {
      throw Exception("You Must Initialize Peer Connection before even attempting data channel creation!");
    }
  }

  /// Sends a Janus `message` with optional SDP negotiation data.
  Future<dynamic> send({dynamic data, RTCSessionDescription? jsep}) async {
    try {
      String transaction = getUuid().v4();
      Map<String, dynamic>? response;
      Map<String, dynamic> request = {"janus": "message", "body": data, "transaction": transaction, ..._context._apiMap, ..._context._tokenMap};
      if (jsep != null) {
        _context._logger.finest("sending jsep");
        _context._logger.finest(jsep.toMap());
        request["jsep"] = jsep.toMap();
      }
      if (_transport is RestJanusTransport) {
        RestJanusTransport rest = (_transport as RestJanusTransport);
        response = (await rest.post(request, handleId: handleId)) as Map<String, dynamic>;
      } else if (_transport is WebSocketJanusTransport) {
        WebSocketJanusTransport ws = (_transport as WebSocketJanusTransport);
        if (!ws.isConnected) {
          return;
        }
        response = await ws.send(request, handleId: handleId);
      }
      return response;
    } catch (e) {
      this._context._logger.fine(e);
    }
  }

  /// Applies the remote [RTCSessionDescription] provided by Janus to this peer connection.
  Future<void> handleRemoteJsep(RTCSessionDescription? data) async {
    // var state = webRTCHandle?.peerConnection?.signalingState;
    if (data != null) {
      await webRTCHandle?.peerConnection?.setRemoteDescription(data);
    }
  }

  /// Initializes device media (camera, microphone, or display capture) and
  /// wires the resulting stream into the plugin's peer connection.
  ///
  /// The default behaviour predicts sensible audio/video constraints when
  /// possible so callers can pass `null` for [mediaConstraints]. To take full
  /// control provide a map compatible with `navigator.mediaDevices`.
  ///
  /// Parameter hints:
  /// - [useDisplayMediaDevices]: set to `true` to capture the screen instead of
  ///   camera input. Required for iOS/macOS screen share support.
  /// - [disableDevicePrediction]: skip automatic audio/video constraint hints
  ///   and rely solely on [mediaConstraints].
  /// - [simulcastSendEncodings]/[transceiverDirection]: advanced knobs for
  ///   unified-plan transceivers (e.g. simulcast in video rooms).
  /// - [desktopCaptureContext]: mandatory when [useDisplayMediaDevices] is true
  ///   on macOS, Windows, or Linux so the native dialog can be presented.
  ///
  /// Platform considerations:
  /// - **Android / iOS:** camera capture works out of the box; screen capture
  ///   requires OS-specific entitlements and typically sets
  ///   [useDisplayMediaDevices] to `true`.
  /// - **Desktop (macOS, Windows, Linux):** provide a valid
  ///   [desktopCaptureContext] to surface `ScreenSelectDialog()` when capturing
  ///   displays. Camera capture uses automatic device prediction when available.
  /// - **Web:** screen capture is also supported; the browser prompts the user
  ///   without requiring [desktopCaptureContext].
  ///
  /// ### Android
  /// ```dart
  /// Future<MediaStream?> initAndroidCamera(JanusPlugin plugin) {
  ///   return plugin.initializeMediaDevices(
  ///     mediaConstraints: {
  ///       'audio': true,
  ///       'video': {'facingMode': 'user'},
  ///     },
  ///   );
  /// }
  /// ```
  ///
  /// ### iOS
  /// ```dart
  /// Future<MediaStream?> initIosScreenShare(
  ///   BuildContext context,
  ///   JanusPlugin plugin,
  /// ) {
  ///   return plugin.initializeMediaDevices(
  ///     useDisplayMediaDevices: true,
  ///     mediaConstraints: {'audio': true, 'video': true},
  ///     desktopCaptureContext: context, // ReplayKit prompt.
  ///   );
  /// }
  /// ```
  ///
  /// ### Desktop (macOS / Windows / Linux)
  /// ```dart
  /// Future<MediaStream?> initDesktopScreenShare(
  ///   BuildContext context,
  ///   JanusPlugin plugin,
  /// ) {
  ///   return plugin.initializeMediaDevices(
  ///     useDisplayMediaDevices: true,
  ///     desktopCaptureContext: context,
  ///   );
  /// }
  /// ```
  Future<MediaStream?> initializeMediaDevices({
    Map<String, dynamic>? mediaConstraints,
    bool useDisplayMediaDevices = false,
    bool disableDevicePrediction = false,
    TransceiverDirection? transceiverDirection = TransceiverDirection.SendOnly,
    List<RTCRtpEncoding>? simulcastSendEncodings,
    BuildContext? desktopCaptureContext,
  }) async {
    await _disposeMediaStreams(ignoreRemote: true);
    Map<String, dynamic>? constraintsCandidate = mediaConstraints != null ? Map<String, dynamic>.from(mediaConstraints) : null;

    if (!disableDevicePrediction) {
      if (!useDisplayMediaDevices) {
        List<MediaDeviceInfo> videoDevices = await getVideoInputDevices();
        List<MediaDeviceInfo> audioDevices = await getAudioInputDevices();
        if (videoDevices.isEmpty && audioDevices.isEmpty) {
          throw Exception("No device found for media generation");
        }
        if (constraintsCandidate == null) {
          if (videoDevices.isEmpty && audioDevices.isNotEmpty) {
            constraintsCandidate = {"audio": true, "video": false};
          } else if (videoDevices.length == 1 && audioDevices.isNotEmpty) {
            constraintsCandidate = {"audio": true, 'video': true};
          } else {
            constraintsCandidate = {
              "audio": audioDevices.isNotEmpty,
              'video': {
                'deviceId': {'exact': videoDevices.first.deviceId},
              },
            };
          }
        }
      } else {
        constraintsCandidate ??= {'audio': true, 'video': true};
      }
    } else {
      if (constraintsCandidate == null) {
        throw Exception("No media constraints set");
      }
    }

    final Map<String, dynamic> resolvedConstraints = Map<String, dynamic>.from(constraintsCandidate);
    _context._logger.fine(resolvedConstraints);
    if (webRTCHandle != null) {
      if (useDisplayMediaDevices == true) {
        final displayConstraints = Map<String, dynamic>.from(resolvedConstraints);
        if (WebRTC.platformIsDesktop) {
          if (desktopCaptureContext == null) {
            throw ArgumentError('desktopCaptureContext is required when capturing display on desktop');
          }
          final source = await showDialog<DesktopCapturerSource>(
            context: desktopCaptureContext,
            builder: (context) => ScreenSelectDialog(),
          );
          if (source == null) {
            _context._logger.fine('desktop screen capture cancelled by user');
            return null;
          }
          final videoConstraints = Map<String, dynamic>.from((displayConstraints['video'] as Map<String, dynamic>?) ?? <String, dynamic>{});
          videoConstraints['deviceId'] = {'exact': source.id};
          final mandatoryConstraints = Map<String, dynamic>.from((videoConstraints['mandatory'] as Map<String, dynamic>?) ?? <String, dynamic>{});
          mandatoryConstraints.putIfAbsent('frameRate', () => 30.0);
          videoConstraints['mandatory'] = mandatoryConstraints;
          displayConstraints['video'] = videoConstraints;
          displayConstraints['audio'] ??= true;
          try {
            webRTCHandle!.localStream = await navigator.mediaDevices.getDisplayMedia(displayConstraints);
          } catch (error) {
            _context._logger.severe('Failed to capture desktop display media: $error');
            rethrow;
          }
        } else {
          webRTCHandle!.localStream = await navigator.mediaDevices.getDisplayMedia(displayConstraints);
        }
      } else {
        webRTCHandle!.localStream = await navigator.mediaDevices.getUserMedia(resolvedConstraints);
      }
      if (_context._isUnifiedPlan && !_context._usePlanB) {
        _context._logger.finest('using unified plan');
        webRTCHandle!.localStream!.getTracks().forEach((element) async {
          if (simulcastSendEncodings == null) {
            await webRTCHandle!.peerConnection!.addTrack(element, webRTCHandle!.localStream!);
            return;
          }
          await webRTCHandle!.peerConnection!.addTransceiver(
              track: element,
              kind: element.kind == 'audio' ? RTCRtpMediaType.RTCRtpMediaTypeAudio : RTCRtpMediaType.RTCRtpMediaTypeVideo,
              init: RTCRtpTransceiverInit(
                  streams: [webRTCHandle!.localStream!], direction: transceiverDirection, sendEncodings: element.kind == 'video' ? simulcastSendEncodings : null));
        });
      } else {
        _localStreamController!.sink.add(webRTCHandle!.localStream);
        await webRTCHandle!.peerConnection!.addStream(webRTCHandle!.localStream!);
      }
      return webRTCHandle!.localStream;
    } else {
      _context._logger.severe("error webrtchandle cant be null");
      return null;
    }
  }

  /// Returns all available video input devices from the underlying platform.
  Future<List<MediaDeviceInfo>> getVideoInputDevices() async {
    return (await navigator.mediaDevices.enumerateDevices()).where((element) => element.kind == 'videoinput').toList();
  }

  /// Returns all available audio input devices from the underlying platform.
  Future<List<MediaDeviceInfo>> getAudioInputDevices() async {
    return (await navigator.mediaDevices.enumerateDevices()).where((element) => element.kind == 'audioinput').toList();
  }

  /// Switches the active camera track to the one referenced by [deviceId].
  ///
  /// When [deviceId] is omitted on web, the helper defaults to the last device
  /// returned by [getVideoInputDevices], which is often the rear-facing camera.
  Future<bool> switchCamera({String? deviceId}) async {
    List<MediaDeviceInfo> videoDevices = await getVideoInputDevices();
    if (videoDevices.isEmpty) {
      throw Exception("No Camera Found");
    }
    if (kIsWeb) {
      if (deviceId == null) {
        _context._logger.finest('deviceId not provided,hence switching to default last deviceId should be of back camera ideally');
        deviceId = videoDevices.last.deviceId;
      }
      await _disposeMediaStreams(ignoreRemote: true);
      webRTCHandle!.localStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'deviceId': {'exact': deviceId}
        },
        'audio': true
      });
      List<RTCRtpSender> senders = (await webRTCHandle!.peerConnection!.getSenders());
      webRTCHandle!.localStream?.getTracks().forEach((element) async {
        senders.forEach((sender) async {
          if (sender.track?.kind == element.kind) {
            await sender.replaceTrack(element);
          }
        });
      });
      return true;
    } else {
      if (webRTCHandle?.localStream != null) {
        _context._logger.finest('using helper to switch camera, only works in android and ios');
        return Helper.switchCamera(webRTCHandle!.localStream!.getVideoTracks().first);
      }
      return false;
    }
  }

  /// Creates an SDP offer and sets it as the local description.
  ///
  /// Supports both Plan-B and Unified Plan flows based on the internal flags.
  Future<RTCSessionDescription> createOffer({bool audioRecv = true, bool videoRecv = true}) async {
    dynamic offerOptions;
    offerOptions = {"offerToReceiveAudio": audioRecv, "offerToReceiveVideo": videoRecv};
    RTCSessionDescription offer = await webRTCHandle!.peerConnection!.createOffer(offerOptions ?? {});
    await webRTCHandle!.peerConnection!.setLocalDescription(offer);
    return offer;
  }

  /// Creates an SDP answer and sets it as the local description.
  Future<RTCSessionDescription> createAnswer() async {
    try {
      RTCSessionDescription answer = await webRTCHandle!.peerConnection!.createAnswer();
      await webRTCHandle!.peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (e) {
      //    handling kstable exception most ugly way but currently there's no other workaround, it just works
      RTCSessionDescription answer = await webRTCHandle!.peerConnection!.createAnswer();
      await webRTCHandle!.peerConnection!.setLocalDescription(answer);
      return answer;
    }
  }

  /// Calculates the bitrate of the inbound video stream identified by [mid].
  ///
  /// When [mid] is omitted, the first inbound video RTP stream is used. This
  /// retains the original string-based API while delegating the heavy lifting to
  /// [mediaStats] so developers can opt into richer statistics when needed.
  Future<String?> getBitrate([String? mid]) {
    return mediaStats.bitrateLabel(
      query: RtpStreamQuery(mid: mid),
      unit: BitrateUnit.kbps,
      fractionDigits: 0,
      suffix: 'kbps',
    );
  }

  /// Returns a strongly typed bitrate measurement that can be formatted or
  /// transformed as desired by the caller.
  ///
  /// When monitoring a local publisher, set [direction] to
  /// [RtpStreamDirection.outbound] so byte counters reflect the proper stats
  /// entry. Supplying [historyKey] is recommended when querying multiple mids
  /// that might rotate identifiers (e.g. replacing transceivers).
  Future<BitrateMeasurement?> getBitrateMeasurement({
    String? mid,
    String? kind,
    RtpStreamDirection direction = RtpStreamDirection.inbound,
    bool fallbackToFirstMatching = true,
    String? trackId,
    String? ssrc,
    String? historyKey,
    bool Function(dynamic report)? where,
    String Function(dynamic report)? historyKeyResolver,
  }) {
    return mediaStats.bitrate(
      query: RtpStreamQuery(
        mid: mid,
        kind: kind ?? 'video',
        direction: direction,
        fallbackToFirstMatching: fallbackToFirstMatching,
        trackId: trackId,
        ssrc: ssrc,
        historyKey: historyKey,
        where: where,
        historyKeyResolver: historyKeyResolver,
      ),
    );
  }

  /// Produces a single network quality snapshot using the underlying stats.
  ///
  /// Default thresholds are tuned for HD video; adjust [thresholds] to match
  /// your bandwidth expectations. Remember to flip [direction] to
  /// [RtpStreamDirection.outbound] when evaluating your own published tracks.
  Future<NetworkQualitySnapshot> getNetworkQuality({
    String? mid,
    String? kind,
    RtpStreamDirection direction = RtpStreamDirection.inbound,
    bool fallbackToFirstMatching = true,
    String? trackId,
    String? ssrc,
    String? historyKey,
    bool Function(dynamic report)? where,
    String Function(dynamic report)? historyKeyResolver,
    NetworkQualityThresholds thresholds = const NetworkQualityThresholds(),
  }) {
    return mediaStats.networkQuality(
      query: RtpStreamQuery(
        mid: mid,
        kind: kind ?? 'video',
        direction: direction,
        fallbackToFirstMatching: fallbackToFirstMatching,
        trackId: trackId,
        ssrc: ssrc,
        historyKey: historyKey,
        where: where,
        historyKeyResolver: historyKeyResolver,
      ),
      thresholds: thresholds,
    );
  }

  /// Continuously samples network quality and emits high-level snapshots.
  ///
  /// Consumers should cancel the returned subscription when the tile is
  /// disposed to avoid leaking timers. Set [emitDistinct] to `false` if you want
  /// periodic updates even when the quality stays the same.
  Stream<NetworkQualitySnapshot> watchNetworkQuality({
    String? mid,
    String? kind,
    RtpStreamDirection direction = RtpStreamDirection.inbound,
    bool fallbackToFirstMatching = true,
    String? trackId,
    String? ssrc,
    String? historyKey,
    bool Function(dynamic report)? where,
    String Function(dynamic report)? historyKeyResolver,
    NetworkQualityThresholds thresholds = const NetworkQualityThresholds(),
    Duration sampleInterval = const Duration(seconds: 2),
    bool emitDistinct = true,
    bool emitOnListen = true,
  }) {
    return mediaStats.watchNetworkQuality(
      query: RtpStreamQuery(
        mid: mid,
        kind: kind ?? 'video',
        direction: direction,
        fallbackToFirstMatching: fallbackToFirstMatching,
        trackId: trackId,
        ssrc: ssrc,
        historyKey: historyKey,
        where: where,
        historyKeyResolver: historyKeyResolver,
      ),
      thresholds: thresholds,
      sampleInterval: sampleInterval,
      emitDistinct: emitDistinct,
      emitOnListen: emitOnListen,
    );
  }

  /// Convenience wrapper that emits only the [NetworkQuality] level.
  ///
  /// Handy for widgets that only care about the label/icon but not the raw
  /// bitrate sample that produced it.
  Stream<NetworkQuality> watchNetworkQualityLevel({
    String? mid,
    String? kind,
    RtpStreamDirection direction = RtpStreamDirection.inbound,
    bool fallbackToFirstMatching = true,
    String? trackId,
    String? ssrc,
    String? historyKey,
    bool Function(dynamic report)? where,
    String Function(dynamic report)? historyKeyResolver,
    NetworkQualityThresholds thresholds = const NetworkQualityThresholds(),
    Duration sampleInterval = const Duration(seconds: 2),
    bool emitDistinct = true,
    bool emitOnListen = true,
  }) {
    return watchNetworkQuality(
      mid: mid,
      kind: kind,
      direction: direction,
      fallbackToFirstMatching: fallbackToFirstMatching,
      trackId: trackId,
      ssrc: ssrc,
      historyKey: historyKey,
      where: where,
      historyKeyResolver: historyKeyResolver,
      thresholds: thresholds,
      sampleInterval: sampleInterval,
      emitDistinct: emitDistinct,
      emitOnListen: emitOnListen,
    ).map((snapshot) => snapshot.quality);
  }

  /// Sends a text [message] over the default data channel.
  ///
  /// Ensure [initDataChannel] has been invoked and the channel is open before
  /// calling this helper. Throws if the peer connection or channel is missing.
  Future<void> sendData(String message) async {
    if (webRTCHandle!.peerConnection != null) {
      _context._logger.finest('before send RTCDataChannelMessage');
      if (webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel] == null) {
        throw Exception("You Must  call initDataChannel method! before you can send any data channel message");
      }
      RTCDataChannel dataChannel = webRTCHandle!.dataChannel[_context._dataChannelDefaultLabel]!;
      if (dataChannel.state == RTCDataChannelState.RTCDataChannelOpen) {
        await dataChannel.send(RTCDataChannelMessage(message));
        return;
      }
    } else {
      throw Exception("You Must Initialize Peer Connection followed by initDataChannel()");
    }
  }
}

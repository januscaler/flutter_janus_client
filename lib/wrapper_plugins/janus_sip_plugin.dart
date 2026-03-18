part of janus_client;

enum SipHoldState { SENDONLY, RECVONLY, INACTIVE }

class JanusSipPlugin extends JanusPlugin {
  bool _onCreated = false;
  JanusSipPlugin({handleId, context, transport, session}) : super(context: context, handleId: handleId, plugin: JanusPlugins.SIP, session: session, transport: transport);

  /// Registers the plugin as a SIP endpoint with the remote registrar.
  ///
  /// Parameters:
  /// - [username]: SIP URI used for registration (e.g. `sip:alice@example.com`).
  /// - [type]: `guest` or `helper` skips the actual SIP REGISTER.
  /// - [sendRegister]: Disables REGISTER exchange when `false`.
  /// - [forceUdp]: Forces SIP messaging over UDP when `true`.
  /// - [forceTcp]: Forces SIP messaging over TCP when `true`.
  /// - [sips]: Registers a SIPS URI alongside the SIP URI.
  /// - [rfc2543Cancel]: Sends CANCEL without provisional response acknowledgement.
  /// - [refresh]: Performs a registration refresh instead of a new registration.
  /// - [secret]: Plain-text password used for authentication.
  /// - [ha1Secret]: MD5 hashed password (HA1) alternative.
  /// - [authuser]: Overrides the authentication username.
  /// - [displayName]: Display name sent in the REGISTER.
  /// - [userAgent]: Custom user-agent header value.
  /// - [proxy]: Registrar or outbound proxy URI.
  /// - [outboundProxy]: Secondary outbound proxy when required.
  /// - [headers]: Custom headers to include in the REGISTER request.
  /// - [contactParams]: Additional parameters appended to the Contact header.
  /// - [incomingHeaderPrefixes]: Custom header prefixes to surface in events.
  /// - [masterId]: References another registered account acting as master.
  /// - [registerTtl]: Overrides the registration TTL in seconds.
  Future<void> register(
    String username, {
    String? type,
    bool? sendRegister,
    bool? forceUdp,
    bool? forceTcp,
    bool? sips,
    bool? rfc2543Cancel,
    bool? refresh,
    String? secret,
    String? ha1Secret,
    String? authuser,
    String? displayName,
    String? userAgent,
    String? proxy,
    String? outboundProxy,
    Map<String, dynamic>? headers,
    List<Map<String, dynamic>>? contactParams,
    List<String>? incomingHeaderPrefixes,
    String? masterId,
    int? registerTtl,
  }) async {
    var payload = {
      "request": "register",
      "type": type,
      "send_register": sendRegister,
      "force_udp": forceUdp, //<true|false; if true, forces UDP for the SIP messaging; optional>,
      "force_tcp": forceTcp, //<true|false; if true, forces TCP for the SIP messaging; optional>,
      "sips": sips, //<true|false; if true, configures a SIPS URI too when registering; optional>,
      "rfc2543_cancel": rfc2543Cancel, //<true|false; if true, configures sip client to CANCEL pending INVITEs without having received a provisional response first; optional>,
      "username": username,
      "secret": secret, //"<password to use to register; optional>",
      "ha1_secret": ha1Secret, //"<prehashed password to use to register; optional>",
      "authuser": authuser, //"<username to use to authenticate (overrides the one in the SIP URI); optional>",
      "display_name": displayName, //"<display name to use when sending SIP REGISTER; optional>",
      "user_agent": userAgent, //"<user agent to use when sending SIP REGISTER; optional>",
      "proxy": proxy, //"<server to register at; optional, as won't be needed in case the REGISTER is not goint to be sent (e.g., guests)>",
      "outbound_proxy": outboundProxy, //"<outbound proxy to use, if any; optional>",
      "headers": headers, //"<object with key/value mappings (header name/value), to specify custom headers to add to the SIP REGISTER; optional>",
      "contact_params": contactParams, //"<array of key/value objects, to specify custom Contact URI params to add to the SIP REGISTER; optional>",
      "incoming_header_prefixes": incomingHeaderPrefixes, //"<array of strings, to specify custom (non-standard) headers to read on incoming SIP events; optional>",
      "refresh": refresh, //"<true|false; if true, only uses the SIP REGISTER as an update and not a new registration; optional>",
      "master_id": masterId, //"<ID of an already registered account, if this is an helper for multiple calls (more on that later); optional>",
      "register_ttl": registerTtl, //"<integer; number of seconds after which the registration should expire; optional>"
    }..removeWhere((key, value) => value == null);
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Accepts an incoming SIP INVITE and negotiates WebRTC when required.
  ///
  /// Parameters:
  /// - [srtp]: Forces SRTP policy (`sdes_mandatory` or `sdes_optional`).
  /// - [headers]: Custom headers to include in the SIP response.
  /// - [autoAcceptReInvites]: Automatically sends 200 OK to re-INVITEs.
  /// - [sessionDescription]: Custom SDP to use; defaults to an answer when
  ///   the signalling state has a remote offer, otherwise falls back to a local offer.
  Future<void> accept({String? srtp, Map<String, dynamic>? headers, bool? autoAcceptReInvites, RTCSessionDescription? sessionDescription}) async {
    var payload = {"request": "accept", "headers": headers, "srtp": srtp, "autoaccept_reinvites": autoAcceptReInvites}..removeWhere((key, value) => value == null);
    RTCSignalingState? signalingState = this.webRTCHandle?.peerConnection?.signalingState;
    if (sessionDescription == null && signalingState == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
      sessionDescription = await this.createAnswer();
    } else if (sessionDescription == null) {
      sessionDescription = await this.createOffer(videoRecv: false, audioRecv: true);
    }
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload, jsep: sessionDescription));
    JanusError.throwErrorFromEvent(response);
  }

  /// Unregisters the current account from the SIP server.
  Future<void> unregister() async {
    const payload = {"request": "unregister"};
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Sends a SIP BYE to terminate the active dialog.
  ///
  /// Parameters:
  /// - [headers]: Extra headers attached to the BYE request.
  Future<void> hangup({
    bool disposeStream = true,
    Map<String, dynamic>? headers,
  }) async {
    super.hangup(disposeStream: disposeStream);
    var payload = {"request": "hangup", "headers": headers}..removeWhere((key, value) => value == null);
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Declines an incoming SIP call with an optional custom response.
  ///
  /// Parameters:
  /// - [code]: SIP response code (defaults to 486 Busy Here).
  /// - [headers]: Additional headers appended to the response.
  Future<void> decline({
    int? code,
    Map<String, dynamic>? headers,
  }) async {
    var payload = {"request": "decline", "code": code, "headers": headers}..removeWhere((key, value) => value == null);
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Places the call on hold using the provided [direction].
  Future<void> hold(
    SipHoldState direction,
  ) async {
    var payload = {"request": "hold", "direction": direction.name};
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Resumes media after a previous [hold] request.
  Future<void> unhold() async {
    var payload = {"request": "unhold"};
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Refreshes the SIP session, typically after header/contact changes.
  Future<void> update() async {
    const payload = {"request": "update"};
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Initiates a SIP INVITE toward [uri] and negotiates a media session.
  ///
  /// Parameters:
  /// - [callId]: Overrides the Call-ID header used for this dialog.
  /// - [referId]: Associates the call with a prior REFER transaction.
  /// - [srtp]: SRTP policy (`sdes_mandatory` or `sdes_optional`).
  /// - [secret]/[ha1Secret]: Credentials used for authentication.
  /// - [authuser]: Overrides the authentication username.
  /// - [headers]: Custom headers included in the INVITE.
  /// - [srtpProfile]: SRTP crypto-suite profile to negotiate.
  /// - [autoAcceptReInvites]: Automatically accepts future re-INVITEs.
  /// - [offer]: Custom WebRTC offer; defaults to audio sendrecv when omitted.
  Future<void> call(String uri,
      {String? callId,
      String? referId,
      String? srtp,
      String? secret,
      String? ha1Secret,
      String? authuser,
      Map<String, dynamic>? headers,
      String? srtpProfile,
      bool? autoAcceptReInvites,
      RTCSessionDescription? offer}) async {
    var payload = {
      "request": "call",
      "call_id": callId,
      "uri": uri,
      "refer_id": referId,
      "headers": headers,
      "autoaccept_reinvites": autoAcceptReInvites,
      "srtp": srtp,
      "srtp_profile": srtpProfile,
      "secret": secret, //"<password to use to register; optional>",
      "ha1_secret": ha1Secret, //"<prehashed password to use to register; optional>",
      "authuser": authuser, //"<username to use to authenticate (overrides the one in the SIP URI); optional>",
    }..removeWhere((key, value) => value == null);
    if (offer == null) {
      offer = await this.createOffer(videoRecv: false, audioRecv: true);
    }
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload, jsep: offer));
    JanusError.throwErrorFromEvent(response);
  }

  /// Transfers the active dialog to another SIP endpoint.
  ///
  /// Parameters:
  /// - [uri]: Destination SIP URI for the transfer.
  /// - [replace]: Call-ID used for attended transfers (replaces existing call).
  Future<void> transfer(
    String uri, {
    String? replace,
  }) async {
    var payload = {"request": "transfer", "uri": uri, "replace": replace}..removeWhere((key, value) => value == null);
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Starts or stops recording of the current SIP session.
  ///
  /// Parameters:
  /// - [state]: `true` to start recording, `false` to stop.
  /// - [audio]/[video]: Record local media when enabled.
  /// - [peerAudio]/[peerVideo]: Record remote media when enabled.
  /// - [filename]: Base path used for generated recording files.
  Future<void> recording(
    bool state, {
    bool? audio,
    bool? video,
    bool? peerAudio,
    bool? peerVideo,
    String? filename,
  }) async {
    var payload = {
      "request": "recording",
      "action": state ? "start" : 'stop',
      "audio": audio,
      "video": video,
      "peer_audio": peerAudio,
      "peer_video": peerVideo,
      "filename": filename
    }..removeWhere((key, value) => value == null);
    JanusEvent response = JanusEvent.fromJson(await this.send(data: payload));
    JanusError.throwErrorFromEvent(response);
  }

  /// Registers typed event mapping specific to the SIP plugin.
  @override
  void onCreate() {
    super.onCreate();
    if (_onCreated) {
      return;
    }
    _onCreated = true;
    messages?.listen((event) {
      TypedEvent<JanusEvent> typedEvent = TypedEvent<JanusEvent>(event: JanusEvent.fromJson(event.event), jsep: event.jsep);
      var data = typedEvent.event.plugindata?.data;
      if (data == null) return;
      if (data["sip"] == "event" && data["result"]?['event'] == "registered") {
        typedEvent.event.plugindata?.data = SipRegisteredEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "unregistered") {
        typedEvent.event.plugindata?.data = SipUnRegisteredEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "ringing") {
        typedEvent.event.plugindata?.data = SipRingingEvent.fromJson(typedEvent.event.plugindata?.data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "calling") {
        typedEvent.event.plugindata?.data = SipCallingEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "proceeding") {
        typedEvent.event.plugindata?.data = SipProceedingEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "accepted") {
        typedEvent.event.plugindata?.data = SipAcceptedEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "progress") {
        typedEvent.event.plugindata?.data = SipProgressEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "incomingcall") {
        typedEvent.event.plugindata?.data = SipIncomingCallEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "missed_call") {
        typedEvent.event.plugindata?.data = SipMissedCallEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data["sip"] == "event" && data["result"]?['event'] == "transfer") {
        typedEvent.event.plugindata?.data = SipTransferCallEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['result']?['code'] != null && data["result"]?['event'] == "hangup" && data['result']?['reason'] != null) {
        typedEvent.event.plugindata?.data = SipHangupEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['sip'] == 'event' && data['error_code'] != null) {
        _typedMessagesSink?.addError(JanusError.fromMap(data));
      }
    });
  }
}

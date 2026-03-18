part of janus_client;

class JanusVideoCallPlugin extends JanusPlugin {
  JanusVideoCallPlugin({handleId, context, transport, session})
      : super(context: context, handleId: handleId, plugin: JanusPlugins.VIDEO_CALL, session: session, transport: transport);

  /// Requests the list of registered peers. Results arrive via plugin events.
  Future<void> getList() async {
    const payload = {"request": "list"};
    await this.send(data: payload);
  }

  /// Registers the local user so they can receive and place calls.
  Future<void> register(String userName) async {
    var payload = {"request": "register", "username": userName};
    await this.send(data: payload);
  }

  /// Updates media or recording preferences for the current call.
  ///
  /// Parameters map directly to the Janus `set` request fields.
  Future<void> set({RTCSessionDescription? jsep, bool? audio, bool? video, int? bitrate, bool? record, String? filename, int? substream, int? temporal, int? fallback}) async {
    var payload = {
      "request": "set",
      "audio": audio,
      "video": video,
      "bitrate": bitrate,
      "record": record,
      "filename": filename,
      "substream": substream,
      "temporal": temporal,
      "fallback": fallback,
    }..removeWhere((key, value) => value == null);
    await this.send(data: payload, jsep: jsep);
  }

  /// Initiates a call toward [userName], creating an offer when one is not provided.
  Future<void> call(String userName, {RTCSessionDescription? offer}) async {
    var payload = {"request": "call", "username": userName};
    if (offer == null) {
      offer = await createOffer(audioRecv: true, videoRecv: true);
    }
    await this.send(data: payload, jsep: offer);
  }

  /// Accepts an incoming call, defaulting to an automatically generated answer.
  Future<void> acceptCall({RTCSessionDescription? answer}) async {
    var payload = {"request": "accept"};
    if (answer == null) {
      answer = await createAnswer();
    }
    await this.send(data: payload, jsep: answer);
  }

  /// Terminates the current call and notifies the remote peer.
  Future<void> hangup({bool disposeStream = true}) async {
    await super.hangup(disposeStream: disposeStream);
    await this.send(data: {"request": "hangup"});
    await dispose();
  }

  bool _onCreated = false;

  /// Maps raw event payloads to strongly typed video-call events.
  @override
  void onCreate() {
    if (_onCreated) {
      return;
    }
    _onCreated = true;
    messages?.listen((event) {
      TypedEvent<JanusEvent> typedEvent = TypedEvent<JanusEvent>(event: JanusEvent.fromJson(event.event), jsep: event.jsep);
      var data = typedEvent.event.plugindata?.data;
      if (data == null) return;
      if (data['videocall'] == 'event' && data['result'] != null && data['result']['event'] == 'registered') {
        typedEvent.event.plugindata?.data = VideoCallRegisteredEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && data['result'] != null && data['result']['event'] == 'calling') {
        typedEvent.event.plugindata?.data = VideoCallCallingEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && data['result'] != null && data['result']['event'] == 'update') {
        typedEvent.event.plugindata?.data = VideoCallUpdateEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && data['result'] != null && data['result']['event'] == 'incomingcall') {
        typedEvent.event.plugindata?.data = VideoCallIncomingCallEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && data['result'] != null && data['result']['event'] == 'accepted') {
        typedEvent.event.plugindata?.data = VideoCallAcceptedEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && data['result'] != null && data['result']['event'] == 'hangup') {
        typedEvent.event.plugindata?.data = VideoCallHangupEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && data['result'] != null && data['result'].containsKey('list')) {
        typedEvent.event.plugindata?.data = VideoCallRegisteredListEvent.fromJson(data);
        _typedMessagesSink?.add(typedEvent);
      } else if (data['videocall'] == 'event' && (data['error_code'] != null || data['result']?['code'] != null)) {
        _typedMessagesSink?.addError(JanusError.fromMap(data));
      }
    });
  }
}

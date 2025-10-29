part of janus_client;

class VideoCallEvent {
  VideoCallEvent({this.videocall, this.result});

  VideoCallEvent.fromJson(dynamic json) {
    videocall = json['videocall'];
    result = json['result'] != null ? Result.fromJson(json['result']) : null;
  }
  String? videocall;
  Result? result;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['videocall'] = videocall;
    if (result != null) {
      map['result'] = result?.toJson();
    }
    return map;
  }
}

class Result {
  Result({this.event, this.username, this.list});

  Result.fromJson(dynamic json) {
    event = json['event'];
    username = json['username'];
    list = List<String>.from(json['list'] ?? []);
  }
  String? event;
  String? username;
  List<String>? list;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['event'] = event;
    map['username'] = username;
    map['list'] = list;
    return map;
  }
}

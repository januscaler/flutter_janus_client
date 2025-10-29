part of janus_client;

class VideoCallRegisteredListEvent extends VideoCallEvent {
  VideoCallRegisteredListEvent.fromJson(dynamic json) {
    videocall = json['videocall'];
    result = json['result'] != null ? Result.fromJson(json['result']) : null;
  }
}

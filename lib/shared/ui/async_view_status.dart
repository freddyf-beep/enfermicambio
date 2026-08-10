enum AsyncState {
  loading,
  ready,
  empty,
  offline,
  permissionDenied,
  backendError,
  stale,
  retryableFailure,
}

class AsyncViewStatus {
  const AsyncViewStatus._(this.state, {this.message});

  const AsyncViewStatus.loading() : this._(AsyncState.loading);

  const AsyncViewStatus.ready() : this._(AsyncState.ready);

  const AsyncViewStatus.empty([String? message])
    : this._(AsyncState.empty, message: message);

  const AsyncViewStatus.offline([String? message])
    : this._(AsyncState.offline, message: message);

  const AsyncViewStatus.permissionDenied([String? message])
    : this._(AsyncState.permissionDenied, message: message);

  const AsyncViewStatus.backendError([String? message])
    : this._(AsyncState.backendError, message: message);

  const AsyncViewStatus.stale([String? message])
    : this._(AsyncState.stale, message: message);

  const AsyncViewStatus.retryableFailure([String? message])
    : this._(AsyncState.retryableFailure, message: message);

  final AsyncState state;
  final String? message;

  bool get isLoading => state == AsyncState.loading;

  bool get isReady => state == AsyncState.ready;

  bool get hasError =>
      state == AsyncState.permissionDenied ||
      state == AsyncState.backendError ||
      state == AsyncState.retryableFailure;
}

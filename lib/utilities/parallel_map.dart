/// Extension to run map operations in parallel
extension ParallelMapExtension<T> on Iterable<T> {
  /// Maps each element in parallel and returns a list of results
  Future<List<R>> parallelMap<R>(Future<R> Function(T) mapper) async {
    return await Future.wait(map(mapper));
  }
}

/// Standard HTTP verbs for RESTful-style communication
enum HttpVerb {
  /// Retrieve a resource
  get,

  /// Create a resource
  post,

  /// Update a resource
  put,

  /// Remove a resource
  delete,

  /// Partially update a resource
  patch,

  /// Retrieve communication options
  options,

  /// Check if a resource exists
  head,
}

# Changelog

## 0.4.0

### Added
- Standardized request/response pattern with `sendRequest()` and `sendResponse()` methods
- Built-in timeout handling for requests
- Validation for response packets
- Comprehensive test suite for request/response functionality
- Documentation and examples for the new methods

## 0.3.0

### Changed
- Bumped minor version for continued development
- Removed unnecessary packet serialization, now passing BusPacket objects directly between isolates

## 0.2.0

### Changed
- Bumped minor version for new development cycle

## 0.1.0 - Initial Release

### Added
- Core messaging infrastructure with URI-based routing
- Flexible verb system supporting custom enum types
- BusPacket for structured message format
- SystemBus for message routing between peers
- SystemBusClient with Future-based API
- HttpSystemBusClient for RESTful operations
- Comprehensive error handling with timeouts
- Logging infrastructure with configurable levels
- Test suite covering core functionality

# Changelog

## 0.5.0

### Breaking Changes
- Removed `result` field from `BusPacket` and consolidated response data into `payload` field
- Removed `SystemBusClient` and `HttpSystemBusClient` classes to reinforce protocol-agnostic design
- Removed `HttpVerb` enum from core package (clients should define their own protocol verbs)

### Added
- Added `errorCode` field to `BusPacket` for more structured error reporting
- Updated documentation with Protocol Implementation Guide section
- Enhanced error reporting in `SystemBus.sendRequest()` to include error codes

### Changed
- Updated tests to reflect new packet structure and removed client-specific tests
- Simplified architecture by removing unnecessary abstractions
- Improved protocol-agnostic approach by eliminating HTTP-specific components

## 0.4.2

### Fixed
- Removed URI scheme restriction that was preventing non-'bus' protocols from utilizing the bus architecture
- SystemBus now routes messages based solely on host and port, without validating or restricting the URI scheme
- Added tests to verify support for domain-specific URI schemes (e.g., 'fs://', 'net://', etc.)

## 0.4.1

### Fixed
- Changed BusPacket.payload type from Map<String, dynamic>? to dynamic? to allow for different types of data to be sent through the bus system

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

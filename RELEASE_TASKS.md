# Release Tasks for system_bus v0.5.0

## Enhancement: BusPacket Structure Improvements

### Tasks

1. [ ] Update the `BusPacket` class to consolidate `result` into `payload` field
   - [ ] Remove the separate `result` field
   - [ ] Modify `BusPacket.response` constructor to accept `payload` instead of `result`
   - [ ] Update all usages of `result` in the codebase to use `payload` instead

2. [ ] Add support for structured error information
   - [ ] Add a `dynamic errorCode` field to `BusPacket` class
   - [ ] Update the `BusPacket.response` constructor to accept `errorCode` parameter
   - [ ] Update the `toString()` method to include `errorCode` in the output

3. [ ] Remove client abstraction layer
   - [ ] Delete the `SystemBusClient` abstract class
   - [ ] Delete the `HttpSystemBusClient` implementation
   - [ ] Delete or move the `HttpVerb` enum to examples
   - [ ] Document the protocol-specific client pattern in README.md

4. [ ] Update documentation
   - [ ] Update class documentation to reflect the change in field usage
   - [ ] Update README.md examples to demonstrate the new structure
   - [ ] Add a "Protocol Implementation Guide" section with a fictional protocol example
   - [ ] Update CHANGELOG.md to document the changes in version 0.5.0

5. [ ] Update tests
   - [ ] Update existing tests to work with the new packet structure
   - [ ] Add new tests for the errorCode functionality
   - [ ] Remove tests for deleted client classes
   - [ ] Verify backward compatibility where possible

6. [ ] Update pubspec.yaml to bump the version to 0.5.0

### Publishing Steps

1. Run `dart format` to ensure code formatting is consistent:
   ```
   dart format .
   ```

2. Run `dart analyze` to check for any linting issues:
   ```
   dart analyze
   ```

3. Run tests to ensure everything is working:
   ```
   dart test
   ```

4. Publish the package to pub.dev:
   ```
   dart pub publish
   ```

### Impact

These changes will streamline the BusPacket structure, enhance error reporting capabilities, and improve architectural alignment:

1. **Simplified Data Model**: Using `payload` for both request and response data creates a more consistent and intuitive API. The existing `isResponse` field is sufficient to disambiguate between request and response contexts.

2. **Enhanced Error Reporting**: The addition of a `dynamic errorCode` field allows for more structured error information, enabling better programmatic error handling while maintaining the protocol-agnostic design philosophy.

3. **Improved Architecture**: Removing the SystemBusClient abstraction reinforces the protocol-agnostic nature of the system_bus package. This change encourages implementing protocol-specific clients that better match real-world usage patterns.

4. **API Changes**: This update introduces breaking changes to the API, as code that previously accessed the `result` field will need to be updated to use `payload` instead, and any code using SystemBusClient will need to be refactored. However, the flexibility gained and the more consistent API justify these changes. 
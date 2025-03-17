# Release Tasks for system_bus v0.4.1

## Bug Fix: BusPacket.payload incorrectly typed as Map instead of dynamic

### Tasks

1. ✅ Change the type of the `payload` field in the `BusPacket` class from `Map<String, dynamic>?` to `dynamic?`
2. ✅ Update the CHANGELOG.md to document the fix in version 0.4.1
3. ✅ Update the pubspec.yaml to bump the version to 0.4.1
4. ✅ Run tests to verify the changes don't break existing functionality
5. ✅ Create this task list document

### Publishing Steps

1. Run `dart format` to ensure code formatting is consistent:
   ```
   dart format .
   ```

2. Run `dart analyze` to check for any linting issues:
   ```
   dart analyze
   ```

3. Run tests one more time to ensure everything is working:
   ```
   dart test
   ```

4. Publish the package to pub.dev:
   ```
   dart pub publish
   ```

### Impact

This change maintains backward compatibility while allowing for more flexible payload types. Users can now send binary data (Uint8List), strings, lists, or any other serializable data type through the bus system, enabling use cases like binary file transfers and streaming data. 
---
description: Proactively connect to running Dart/Flutter apps and trigger hot reload or hot restart upon editing .dart files under lib/.
trigger: glob
globs: "**/lib/**/*.dart"
---

# Proactive Flutter Hot Reload Rule

Whenever you edit or modify any `.dart` file under `lib/` in this project:

1. **When to Skip**:
   - **Files Outside `lib/`**: Only trigger hot reload or hot restart for edits under `lib/`. Do not trigger when modifying files in other directories (e.g., `test/**`, `integration_test/**`, `benchmark/**`, `test_driver/**` or `example/**`).
   - **Comments & Documentation**: Do not trigger hot reload or hot restart when changes only affect comments, docstrings, or whitespace.

2. **Discover & Connect**:
   - Connect with the Dart MCP server's `dtd` tool before `hot_reload` or `hot_restart`. Call `listDtdUris`, then `connect` with that URI. A DTD whose working directory looks like a home directory is an IDE session. There is no `list_running_apps` tool. When more than one app is connected, pass `appUri`.

3. **Trigger Hot Reload / Hot Restart**:
   - Execute the `hot_reload` MCP tool immediately after making changes to UI widgets (including `build` methods of stateful widgets) or simple methods.
   - Execute the `hot_restart` MCP tool if fundamental logic, state initialization (e.g., `initState`), global/static state, or `main()` was modified.

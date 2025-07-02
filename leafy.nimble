version     = "1.0.0"
author      = "Monofuel"
description = "Gitea API client library for Nim"
license     = "MIT"

srcDir = "src"

requires "nim >= 2.0.0"
requires "curly"
requires "jsony"

task test, "Run unit tests":
  exec "nim c -r tests/test.nim"

task integration, "Run integration tests":
  exec "nim c -r tests/integration_test.nim"

task test_all, "Run all tests (unit + integration)":
  exec "nim c -r tests/test.nim"
  exec "nim c -r tests/integration_test.nim"

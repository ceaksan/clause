# Clause - Project Instructions

## Stack
- Swift 6, SwiftUI, AppKit, Network.framework
- Xcode 16+ with 3 targets: ClauseShared, ClauseMCP, ClauseApp
- modelcontextprotocol/swift-sdk for MCP protocol
- macOS 14+ (Sonoma) minimum deployment target

## Build
- Open Clause.xcodeproj in Xcode
- Or: xcodebuild -scheme ClauseApp -configuration Debug build
- Or: xcodebuild -scheme ClauseMCP -configuration Debug build

## Architecture
Two-process model: ClauseMCP (CLI, stdio MCP) <-> Unix socket <-> ClauseApp (SwiftUI window)
See docs/superpowers/specs/2026-03-21-clause-design.md for full spec.

## Conventions
- Swift Testing framework (@Test, #expect) for all tests
- @Observable for state management (not ObservableObject)
- Structured concurrency (async/await, actors)
- All UI state mutations on @MainActor

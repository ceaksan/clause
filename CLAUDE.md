# Clause - Project Instructions

## Stack
- Swift 6, SwiftUI, AppKit, Network.framework
- Xcode 16+ with 3 targets: ClauseShared, ClauseMCP, ClauseApp
- modelcontextprotocol/swift-sdk for MCP protocol
- macOS 14+ (Sonoma) minimum deployment target

## Build
- Open Clause.xcodeproj in Xcode
- Or: xcodebuild -scheme Clause -configuration Debug build
- Or: xcodebuild -scheme ClauseMCP -configuration Debug build

## Architecture
Two-process model: ClauseMCP (CLI, stdio MCP) <-> Unix socket <-> ClauseApp (SwiftUI window)
Current design: docs/superpowers/specs/2026-11-07-clause-herdr-board-design.md (herdr multi-workspace board, ADR-001).
Original single-session design: docs/superpowers/specs/2026-03-21-clause-design.md (superseded).
After adding or deleting a Swift file, run `xcodegen generate`; the generated project is committed.

## Conventions
- Swift Testing framework (@Test, #expect) for all tests
- @Observable for state management (not ObservableObject)
- Structured concurrency (async/await, actors)
- All UI state mutations on @MainActor

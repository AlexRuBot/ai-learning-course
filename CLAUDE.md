# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI-based iOS application project named "ai-learning-course". The project uses Xcode as its IDE and follows standard iOS development patterns.

## Project Structure

```
ai-learning-course/
├── ai-learning-course/          # Main source directory
│   ├── ai_learning_courseApp.swift  # App entry point (@main)
│   ├── ContentView.swift        # Root view
│   └── Assets.xcassets/         # Asset catalog
├── ai-learning-course.xcodeproj/    # Xcode project configuration
└── README.md
```

## Development Commands

### Building and Running
- Open the project in Xcode: `open ai-learning-course.xcodeproj`
- Build from command line: `xcodebuild -project ai-learning-course.xcodeproj -scheme ai-learning-course build`
- Run tests: `xcodebuild test -project ai-learning-course.xcodeproj -scheme ai-learning-course -destination 'platform=iOS Simulator,name=iPhone 15'`

### Common Xcode Operations
- Clean build: `xcodebuild clean -project ai-learning-course.xcodeproj -scheme ai-learning-course`
- Archive for distribution: `xcodebuild archive -project ai-learning-course.xcodeproj -scheme ai-learning-course -archivePath ./build/ai-learning-course.xcarchive`

## Architecture

### SwiftUI Application
- **Entry point**: `ai_learning_courseApp.swift` contains the `@main` app struct with a `WindowGroup` scene
- **Root view**: `ContentView.swift` is the initial view loaded by the app
- **View system**: Uses SwiftUI's declarative view syntax with `View` protocol conformance

### Code Organization
- All Swift source files currently reside in the `ai-learning-course/` directory
- Assets (app icons, colors, images) are managed through `Assets.xcassets` catalog
- Standard iOS .gitignore excludes build artifacts, user data, and package dependencies

## Key Conventions

- Swift files follow standard naming: PascalCase for types, camelCase for properties/methods
- SwiftUI preview macros (`#Preview`) are used for UI development
- App uses SwiftUI lifecycle (not UIKit AppDelegate)

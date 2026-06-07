# ASCamera

A small, safe, SwiftUI-first Swift Package for **custom camera preview and video recording** on
iOS 17+. It hides AVFoundation behind a tiny, concurrency-friendly API and ships only the camera
preview and control surface — **you build your own UI**.

- 🎥 Video recording only (no photo capture).
- 🧩 SwiftUI preview view + plain control APIs. No buttons, overlays, or controls baked in.
- 🔒 Validated, thread-safe state machine — no double-start, no stop-when-idle, no races.
- ⏱️ Built-in recording duration tracking (`Duration`, not `TimeInterval`) and a live stream.
- 🔁 Orientation lock that applies to **both** preview and exported video.
- ⚙️ Strongly-typed, extensible configuration (builder *or* mutable struct).
- 🧪 Fully unit-tested core (state, permissions, recording, duration, auto-stop, orientation).
- 🛡️ Swift 6 strict concurrency, no force-unwraps/force-tries, SwiftLint clean.

---

## Quick start

```swift
import ASCamera
import SwiftUI

struct RecorderView: View {
    @State private var camera = Camera()

    var body: some View {
        CameraPreview(camera: camera)
            .ignoresSafeArea()
            .task { try? await camera.start() }
    }
}
```

Recording is controllable from anywhere — a view, a view model, a coordinator, or any async task:

```swift
try await camera.startRecording()              // silent: library picks the file
let result = try await camera.stopRecording()  // -> RecordingResult(url, duration, fileSize)
```

Add the usage descriptions to your app's Info.plist:

```xml
<key>NSCameraUsageDescription</key><string>Records video.</string>
<key>NSMicrophoneUsageDescription</key><string>Records audio.</string>
```

---

## Architecture

ASCamera is layered so that the **public surface stays tiny** and AVFoundation never leaks to
consumers. The main-actor, observable `Camera` facade is the only object an app touches; all
capture work happens behind an internal `CameraEngine` protocol.

```text
          ┌──────────────────────────────────────────────────────────────┐
          │  Consumer (SwiftUI views, view models, coordinators)          │
          └───────────────┬───────────────────────────┬──────────────────┘
                          │ observes / calls            │ displays
                          ▼                             ▼
          ┌───────────────────────────────┐   ┌──────────────────────────┐
          │  Camera  (@MainActor @Observable) │ │  CameraPreview (SwiftUI) │
          │  • state machine (validated)    │   │  CameraPermissionErrorView│
          │  • duration / finished streams  │   └──────────────────────────┘
          │  • permission flow              │
          │  • device-orientation → angle   │
          └───────────────┬───────────────┘
                          │  `any CameraEngine`  (protocol seam → testable)
                          ▼
          ┌───────────────────────────────────────────────┐
          │  CameraSession (actor)  — production engine     │
          │  • AVCaptureSession + AVCaptureMovieFileOutput   │
          │  • device/format selection                      │
          │  • interruption / runtime-error recovery        │
          │  • emits CameraEngineEvent (progress, finished…) │
          └───────────────────────────────────────────────┘
```

### Why these boundaries

- **`Camera` is `@MainActor` + `@Observable`.** State and duration live on the main actor, so
  SwiftUI observes them with zero ceremony, and the recording-safety state machine never races.
- **The capture engine is an `actor` behind a protocol.** `AVCaptureSession` is mutated on a
  single isolation domain. The protocol seam (`CameraEngine`) lets the entire lifecycle —
  recording, duration ticks, max-duration auto-stop, interruptions — be unit-tested with a fake,
  no camera hardware required.
- **Request/response vs. events.** `start`/`stop`/`startRecording` are `async` functions;
  everything unsolicited (progress ticks, auto-stop, interruptions) flows back as
  `CameraEngineEvent`s the `Camera` reduces into observable state.
- **Orientation is split by responsibility but driven by one source of truth.** Device-orientation
  reading stays on the main actor (`Camera`), which resolves a single rotation angle (via the pure
  `OrientationResolver`) and pushes it to *both* the preview layer and the recording connection.
- **One narrow `@unchecked Sendable` bridge.** Only the `AVCaptureSession` reference crosses to the
  main-actor preview layer, via `UncheckedSendableBox` — isolated and documented.

### Pure, testable core

These types contain no AVFoundation/UIKit/concurrency and are exhaustively unit-tested:

| Type | Responsibility |
|------|----------------|
| `CameraStateMachine` | Validates every state transition (anti double-start / stop-when-idle). |
| `OrientationResolver` | Maps strategy + device orientation → rotation angle. |
| `RecordingOutcome` | Classifies a finish error as "usable file" vs "failure" (max-duration = success). |
| `CameraConfiguration` | Value-semantic, builder-style options. |

---

## Folder structure

```text
Sources/ASCamera/
├─ Camera.swift                     # Public @MainActor @Observable facade (the entry point)
├─ CameraState.swift                # Public lifecycle states
├─ CameraStateMachine.swift         # Pure, validated transitions (tested)
├─ CameraError.swift                # Public, Equatable error type
├─ RecordingResult.swift            # Public result value type
├─ Configuration/
│  ├─ CameraConfiguration.swift     # Mutable + builder-style options
│  ├─ CameraPosition.swift          # .front / .back
│  ├─ FrameRate.swift               # .fps24/30/60/120/240, validated
│  ├─ Resolution.swift              # .hd / .fullHD / .uhd4K
│  ├─ TorchMode.swift               # .on / .off / .auto (graceful if unsupported)
│  ├─ VideoStabilizationMode.swift  # off/standard/cinematic/…/auto
│  └─ OrientationStrategy.swift     # device / lockedPortrait / lockedLandscape{Left,Right}
├─ Permissions/
│  ├─ PermissionStatus.swift        # Public status enum
│  ├─ AuthorizationProviding.swift  # Internal protocol (+ AVFoundation impl) → testable
│  └─ CameraPermissions.swift       # Public facade for pre-flight checks
├─ Session/
│  ├─ CameraEngine.swift            # Internal engine protocol + events (the test seam)
│  ├─ CameraSession.swift           # Production actor: AVCaptureSession + movie output
│  └─ CameraDeviceDiscovery.swift   # Device + format selection
├─ Recording/
│  ├─ MovieRecordingDelegate.swift  # Bridges AVFoundation delegate → @Sendable closures
│  └─ RecordingOutcome.swift        # Pure finish-error classification (tested)
├─ Orientation/
│  └─ OrientationResolver.swift     # Pure strategy → rotation-angle mapping (tested)
├─ Preview/
│  ├─ CameraPreview.swift           # Public SwiftUI UIViewRepresentable
│  └─ PreviewMetalView.swift        # UIView backed by AVCaptureVideoPreviewLayer
├─ UI/
│  └─ CameraPermissionErrorView.swift  # Public ready-to-use permission screen
└─ Support/
   ├─ Duration+Media.swift          # Duration ↔ CMTime
   └─ UncheckedSendableBox.swift    # The single, documented Sendable bridge

Tests/ASCameraTests/                # 47 tests across 10 suites
Examples/ASCameraExample/           # Buildable example app (XcodeGen project, 2 screens)
```

---

## State diagram

```text
                 start() [perm OK]            startRecording()
   ┌────────┐  ───────────────────▶ ┌─────────┐ ─────────────▶ ┌───────────┐
   │  idle  │                       │ running │                │ recording │
   └────────┘  ◀───── stop() ─────  └─────────┘ ◀──────┐       └─────┬─────┘
        ▲                              ▲   ▲           │             │ stopRecording()
        │                       finish │   │ finish    │             ▼
        │                     (auto或   │   │           │      ┌──────────────────┐
        │                      explicit)│   └───────────┴───── │ stoppingRecording│
        │                              │                       └──────────────────┘
        │   start() in progress        │
        │        ┌──────────┐          │
        └─────── │ starting │ ─────────┘
                 └────┬─────┘
        permission ▼      ▼ config/runtime error
        ┌────────────────┐  ┌──────────────────┐
        │ permissionDenied│  │ failed(CameraError)│   (both can start() again)
        └────────────────┘  └──────────────────┘
```

Illegal transitions are rejected before any AVFoundation call:

- `startRecording()` while recording → `CameraError.recordingAlreadyInProgress`
- `startRecording()` while not running → `CameraError.sessionNotRunning`
- `stopRecording()` with no active recording → `CameraError.noRecordingInProgress`

---

## Public API

### `Camera`

```swift
@MainActor @Observable
public final class Camera {
    public init(configuration: CameraConfiguration = CameraConfiguration())

    // Observable state
    public var state: CameraState { get }
    public private(set) var currentRecordingDuration: Duration
    public private(set) var lastRecordingResult: RecordingResult?
    public private(set) var configuration: CameraConfiguration
    public var cameraPermission: PermissionStatus { get }
    public var microphonePermission: PermissionStatus { get }

    // Lifecycle
    public func start() async throws
    public func stop() async
    public func updateConfiguration(_ configuration: CameraConfiguration) async throws

    // Recording
    public func startRecording() async throws                 // library-generated file
    public func startRecording(outputURL: URL) async throws   // your file
    @discardableResult public func stopRecording() async throws -> RecordingResult

    // Duration & results
    public func recordingDurationStream() -> AsyncStream<Duration>
    public func recordingFinishedStream() -> AsyncStream<RecordingResult>
}
```

### Configuration (builder *or* mutable)

```swift
// Builder style
let config = CameraConfiguration()
    .position(.front)
    .frameRate(.fps60)
    .resolution(.uhd4K)
    .torch(.auto)
    .audioEnabled(true)
    .stabilization(.cinematic)
    .orientation(.lockedPortrait)
    .maximumRecordingDuration(.seconds(30))

// Mutable style
var c = CameraConfiguration()
c.position = .back
c.maximumRecordingDuration = .seconds(30)
```

New options are added as new properties with defaults, so call sites keep compiling — no giant
initializers.

### Duration tracking

No timers needed. Duration starts at zero per recording, updates continuously, resets on the next
recording, and is based on actual recording progress:

```swift
.task {
    for await duration in camera.recordingDurationStream() {
        label = duration.formatted()   // Duration, not TimeInterval
    }
}
```

### Maximum duration auto-stop

Set `maximumRecordingDuration` and the library stops on its own, delivering a **normal**
`RecordingResult` through `recordingFinishedStream()` (since no `stopRecording()` caller is awaiting):

```swift
.task {
    for await result in camera.recordingFinishedStream() {
        save(result.url)   // also fires for explicit stops
    }
}
```

### Orientation lock

```swift
let camera = Camera(configuration: CameraConfiguration().orientation(.lockedPortrait))
```

The locked angle is applied to the preview connection **and** the recording connection, so the
exported video orientation matches what the user saw — independent of device rotation. `.device`
follows the physical orientation.

### Permissions

`start()` checks camera (always) and microphone (when audio is enabled) and will not start the
preview if either is missing — the state becomes `.permissionDenied`. Use the ready-made screen:

```swift
if camera.state == .permissionDenied {
    CameraPermissionErrorView(missing: .both)   // explains + opens Settings
}
```

Or pre-flight yourself with `CameraPermissions.cameraStatus` / `requestCameraAccess()`.

---

## Lifecycle & recovery

`CameraSession` observes interruptions (phone calls, backgrounding, resource contention), runtime
errors, and app activation, and **resumes the session automatically** when possible. An in-progress
recording interrupted by the system is finalized into a usable file and surfaced as a result.

---

## Requirements

- iOS 17+, Swift 6, Xcode 16+ (developed against Xcode 26 / iOS 26 SDK).
- AVFoundation. SwiftUI. No third-party dependencies. Minimal Combine usage (none).

## Testing

```bash
xcodebuild test -scheme ASCamera -destination 'platform=iOS Simulator,name=iPhone 17'
```

47 tests across 10 suites cover state transitions, permission handling, the recording lifecycle,
duration tracking, maximum-duration auto-stop, orientation handling, and the embedded start-time
metadata — all without camera hardware, thanks to the `CameraEngine` / `AuthorizationProviding`
protocol seams.

## Example app

A complete, buildable example with **two different recorder layouts** lives in
[`Examples/ASCameraExample`](Examples/ASCameraExample) — open the `.xcodeproj`, set your signing
team, and run on a device. It also demonstrates reading the recording-start timestamp back out of
each recorded file. See its [README](Examples/ASCameraExample/README.md).

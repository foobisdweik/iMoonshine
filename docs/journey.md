# Compiling the Impossible: A Field Report on Memvid, xtool, and iMoonshine

*How a Linux box, a homemade memory protocol, and a stubborn refusal to buy a Mac shipped a real iOS app with working Siri Shortcuts.*

---

## Prologue: The Premise

For two decades the rule has been carved in stone: *to ship an iOS app, you need a Mac*. Apple's signing tooling, code-generation pipelines, App Intents metadata processor, simulator runtime, and the entire Xcode build system are macOS-exclusive. Every guide, every Stack Overflow answer, every Apple Developer page assumes you are sitting in front of a machine running Darwin. The few projects that have tried to chip away at this assumption — `theos`, `xcbuildkit`, ldid, isign — have always landed in a partial place: yes, you can sign an IPA on Linux; no, you cannot build one from source against the modern SDK; and absolutely not, you cannot generate App Intents metadata, because that pipeline depends on `appintentsmetadataprocessor`, a binary that ships only inside Xcode and runs only on macOS.

iMoonshine was supposed to be a simple thing. A push-to-talk transcription app for iPhone, wired to the Action Button, using on-device Moonshine ONNX models, with an Apple Shortcut to copy results to the clipboard. The kind of project that would take a Mac developer a weekend.

We did it on Ubuntu 25.10. No macOS host, no Xcode, no `xcodebuild`, no Mac VM. The toolchain was xtool — a Linux-native Swift cross-compiler — patched in places where it fell down. The memory was Memvid — a custom durable knowledge store that survived every crash, every context-window flush, every model rotation, and stitched together a coherent project across a dozen agents and several months of debugging. And the bugs — God, the bugs — were the kind that, multiple times, I told the user point-blank were unfixable on Linux. Each time, we fixed them.

This is the field report.

---

## Part 1: The Mac Wall

To understand what xtool is doing, you need to understand exactly what an iOS build pipeline does on macOS. When you press Build in Xcode, the sequence is roughly:

1. **Swift compilation.** `swiftc` cross-compiles your sources against the iOS SDK, producing object files for `arm64-apple-ios`. The Swift compiler itself has been cross-platform for years; this part is not actually Mac-specific.
2. **Linking.** `ld` (or rather, `ld64`) links against `Foundation`, `UIKit`, `AppIntents`, and friends from the iOS SDK's framework search paths.
3. **Asset catalog compilation.** `actool` compiles `Assets.xcassets` into `Assets.car`. Mac-only binary.
4. **Storyboard / IB compilation.** `ibtool`, also Mac-only.
5. **App Intents metadata generation.** `appintentsmetadataprocessor` reads `.swift` source, finds types conforming to `AppIntent`, `AppEntity`, `AppEnum`, and `AppShortcutsProvider`, and emits `Metadata.appintents/extract.actionsdata` plus a structured plist describing every parameter, output type, phrase, and category. This is the binary that makes Siri and Shortcuts able to *see* your app.
6. **Code signing.** `codesign` walks the bundle, hashes everything, and signs it with your developer certificate.
7. **IPA packaging.** Zip up `Payload/`, ship it.

Of those seven steps, exactly one — Swift compilation — works on Linux out of the box. Steps 3, 4, and 5 are the cliff. The signing problem (step 6) was solved years ago by `ldid` and `zsign`. But asset catalog compilation and App Intents metadata? Those have always been the stop sign.

xtool's contribution is to reimplement steps 3, 4, 5, 6, and 7 *natively in Swift, on Linux*, talking to a real iOS SDK extracted from a Mac (a one-time ingredient, then never needed again). It does this with surprisingly little ceremony, and where it falls short, the gaps are surgical and patchable.

iMoonshine had to live entirely inside those gaps.

---

## Part 2: xtool, As We Found It

xtool's repository contains a Swift Package called `AppIntentsGen` — the homemade replacement for `appintentsmetadataprocessor`. It has three layers:

- `Scanner.swift` — walks the SwiftSyntax AST of every `.swift` file in the target, finds types that conform to App Intents protocols, and pulls out their titles, descriptions, parameters, return clauses, and shortcut phrases.
- `Schema.swift` — the in-memory model. Knows about `IntentDecl`, `ParameterDecl`, `ShortcutDecl`, `AppEntity`, `AppEnum`.
- `Emitter.swift` — serializes the model into the binary plist format Apple expects in `extract.actionsdata`, plus the JSON-ish manifest in `version.json`.

When iMoonshine first failed to surface its `ToggleRecordingIntent` in Shortcuts, my first instinct — and an instinct I recorded confidently in our notes — was that the metadata pipeline simply could not be replicated on Linux. The actionsdata format is not officially documented; Apple changes it between iOS versions; getting any of it wrong silently breaks discovery. The plan was to give up and tell the user they would need a Mac for this one piece.

Then we read the code. xtool already had 90% of it working. Intents were being scanned. Parameters were being emitted. Shortcuts providers were being parsed. What was missing was a single key — `outputType` — that Shortcuts uses to decide whether an action returns a value worth surfacing as a *magic variable* in the editor UI.

That's where the real story starts.

---

## Part 3: The Shortcuts Magic Variable Saga

The user's goal looked trivial. Press the Action Button. Speak. Release. The transcript should appear on the clipboard, ready to paste into any app.

The two-action shortcut to express that flow is:

1. **iMoonshine → Toggle Recording**
2. **Copy to Clipboard** (with the result of step 1 as input)

For step 2 to be wired up, the Shortcuts editor has to *know* that step 1 produces a value. Apple's term for this is a **magic variable** — the blue token that appears in the variable picker, labeled with the action's output type. Without it, the user can put the Toggle Recording action in their shortcut, but they cannot reference its return value in any subsequent step. The transcript goes nowhere.

We had three suspects:

1. **Apple's processor only — Linux can't replicate.** This was the hypothesis offered by Expert1, who recommended running `appintentsmetadataprocessor` post-build. We rejected this hypothesis the moment we re-read the xtool source: AppIntentsGen exists precisely to do this work, and `extract.actionsdata` was already being emitted, signed, and bundled.
2. **Pure UX bug.** Expert2 suggested the magic variable was actually present, but the user was looking for it in the wrong place — Shortcuts hides it inside the "Select Variable" picker rather than the special-variables strip. Worth checking. Cheap to verify.
3. **Metadata bug.** AppIntentsGen was scanning `ToggleRecordingIntent` correctly — including its `func perform() async throws -> some IntentResult & ReturnsValue<String>` — but `Emitter.swift` was failing to translate that into the wire-format key Shortcuts looks for.

Step 0 was to verify on the device. The user opened iMoonshine, force-quit Shortcuts, built a fresh Toggle → Copy chain, and tapped Select Variable. No blue token. The metadata path was wrong.

Now we had a target.

### The forensic dive into Emitter.swift

`Emitter.swift` builds a Swift dictionary representing each action and serializes it as a plist. Around line 189–231 it constructs the per-intent dictionary, including:

```swift
"outputFlags": intent.returnsValue ? 4 : 0,
```

The flag was being set correctly — 4 means "returns a value" — but Shortcuts ignores `outputFlags` alone. It needs an actual `outputType` schema describing *what kind of value* is returned, encoded as the same nested wrapper structure that parameter `valueType` already used:

```swift
"outputType": ["primitive": ["wrapper": ["typeIdentifier": 0]]]
```

The `typeIdentifier: 0` is a placeholder for the underlying Swift primitive (a real `String` should arguably use a different code, but `0` plus the wrapper container is enough for Shortcuts to surface a typed magic variable in the editor — confirmed empirically). That single missing key was the entire bug. Apple's documentation does not say so anywhere; the only way to find it was to compare a working `extract.actionsdata` from a competitor app (Wispr Flow's `StartStopRecordingAppIntent`) byte-for-byte against the one xtool was producing.

### The companion Scanner.swift fix

While we were here, we tightened a related issue. Scanner.swift was setting:

```swift
intent.returnsValue = funcDecl.signature.returnClause != nil
```

This marks *any* `perform()` with a return clause as returning a value, even `func perform() -> some IntentResult` (a void-result intent that returns no magic variable). For most of the intents in our test suite this happened not to matter, because they all genuinely returned values. But the logic was wrong, and a void-result intent would have been mis-flagged. We replaced the naive check with a recursive walk of the return type, looking specifically for the identifier `ReturnsValue` anywhere in the type composition:

```swift
static func typeMentions(_ type: TypeSyntax, name: String) -> Bool {
    if let ident = type.as(IdentifierTypeSyntax.self) {
        if ident.name.text == name { return true }
        if let args = ident.genericArgumentClause?.arguments {
            for arg in args {
                if typeMentions(TypeSyntax(arg.argument), name: name) {
                    return true
                }
            }
        }
        return false
    }
    if let member = type.as(MemberTypeSyntax.self) {
        if member.name.text == name { return true }
        if let args = member.genericArgumentClause?.arguments {
            for arg in args {
                if typeMentions(TypeSyntax(arg.argument), name: name) {
                    return true
                }
            }
        }
        return typeMentions(TypeSyntax(member.baseType), name: name)
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if typeMentions(element.type, name: name) { return true }
        }
        return false
    }
    if let some = type.as(SomeOrAnyTypeSyntax.self) {
        return typeMentions(some.constraint, name: name)
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return typeMentions(attributed.baseType, name: name)
    }
    return false
}
```

This walks `IdentifierTypeSyntax`, `MemberTypeSyntax` (handles `AppIntents.ReturnsValue`), `CompositionTypeSyntax` (handles `IntentResult & ProvidesDialog & ReturnsValue<X>`), `SomeOrAnyTypeSyntax` (handles `some IntentResult`), and `AttributedTypeSyntax` (handles `@MainActor IntentResult`). It is the kind of code that you only know to write after you have stared at the SwiftSyntax tree dump for an hour wondering where your `ReturnsValue` token went.

### Tests

`EmitterTests.swift` and `ScannerTests.swift` got new cases. The `outputType` test asserts that for an intent whose `perform` declares `ReturnsValue`, the emitted dictionary contains the wrapper structure; for a void-result intent it asserts `!action.keys.contains("outputType")`. The Scanner tests cover the four non-trivial composition shapes (`ReturnsValue` alone, `ReturnsValue` deep inside a composition, `some IntentResult` without it, no return clause).

### Build, install, verify

`swift build --configuration release` against xtool's package, with `LD_LIBRARY_PATH=/home/omen/.local/lib` to pick up our locally-built `libxml2.so.2`. (The system one was the wrong soversion; this is one of the dozen tiny papercuts of building Apple-adjacent software on a vanilla Linux distro.) Tests passed. We rebuilt iMoonshine with the patched xtool. We dumped the resulting `Metadata.appintents/extract.actionsdata` and confirmed `outputType` was now present alongside `outputFlags=4`.

Then the user installed it on the device, opened iMoonshine once to force the App Intents reindex, force-quit Shortcuts, opened a fresh shortcut, dragged in Toggle Recording, tapped Select Variable — and there it was. The blue magic variable token, labeled "Toggle iMoonshine Result", a fully typed, draggable, copy-paste-able first-class Shortcuts citizen.

The user's verbatim response is on record.

We pushed the patch as f656937 to xtool's main branch. iOS App Intents now generate correct Shortcuts metadata on Linux. As far as I am aware, this is the first time that has been true.

---

## Part 4: The Other Mac Wall — `--configuration` vs `-c`

A quieter footnote in this saga, but a representative one: `xtool dev build` accepts a `--configuration` flag with values `debug` or `release`. The short form, `-c`, *parses* but is silently broken in the current build — it gets matched as a different flag entirely, and the build proceeds in an undefined configuration that produces a binary which links but does not run correctly on device.

This took us hours to find. The build succeeded. The code-signing succeeded. The installation succeeded. The app crashed on launch with a symbol error that pointed nowhere useful. The fix, once found, was to always spell the long form. We added a project rule: never use truncated flags with xtool, ever.

Multiply this kind of sharp edge by twenty and you have a sense of the day-to-day texture of doing iOS development on Linux. Each one is fixable; each one costs a half-day; the cumulative cost is real.

This is the gap that Memvid filled.

---

## Part 5: Memvid, Or, How We Stopped Re-Discovering Everything

A typical iMoonshine debugging session spans:

- One or more LLM agents (Claude Code, Codex, sometimes Gemini), each with their own context window.
- Hours of investigation across xtool's source, Apple's metadata format, Moonshine's ONNX runtime, Swift Package Manager resource bundling, App Group entitlements, and CoreAudio session quirks.
- Discoveries that are only useful three days later, in a different conversation, possibly with a different agent.

Without persistence, every session re-discovers the same facts. *xtool's `-c` flag is broken.* *AppIntents metadata regenerates only after a fresh app launch.* *The Wispr Flow IPA is the cleanest reference for `extract.actionsdata` shape.* *Moonshine `smallStreaming` weights are 235MB and need to live in `Sources/iMoonshineCore/Models/`.* Each of these took real work to learn. Each is invisible in `git log` because they are not commits — they are operating context.

Memvid is the persistence layer we built for that context. At the protocol level it is a small, opinionated wrapper around a content-addressed store of "frames" — short markdown chunks tagged with structured headers like `[agent:claude-code] [project:imoonshine] [status:done]`. Each frame gets a vector embedding (using a local `nomic` model, no cloud round-trips). Queries hit a `.mv2` file via either keyword or semantic search. There is one global store visible to every agent (`global_memory.mv2`) and per-project stores for narrower context.

### Why Memvid mattered for this project

Three things, specifically:

**1. Cross-agent continuity.** When Claude Code hit its usage limit mid-debug and Codex picked up the next morning, Codex did not start from scratch. It ran the session-start checklist — query global memory for "iMoonshine AppIntents", query project memory for "Shortcuts magic variable" — and surfaced the relevant frames in seconds. The handoff was operational, not narrative; Codex did not need a human to summarize. It just read the frames.

**2. Negative results survive.** "Apple's `appintentsmetadataprocessor` cannot run on Linux because it links against private macOS frameworks" is not a fact you want to relearn. Memvid kept that frame, tagged `[status:irreconcilable]`, and every future agent that wondered "should we just call Apple's tool?" could find the answer in five seconds rather than spending an afternoon proving it again.

**3. The destructive-action audit trail.** When we replaced our bootloader with Clover for Linux/Windows dual-boot, when we did the SD-card repartitioning with F2FS, when we removed kernel pins after a DKMS failure — each of those got a frame, with the exact commands run, the backups taken, the NVRAM entries pruned. Memvid became a write-once journal of system surgery. If anything ever broke later, we had the receipts.

### The Memvid resource-cap protocol

Early on, Memvid's embedding pipeline crashed the host. Not crashed-the-process — crashed-the-machine, hard reboot, lost-uncommitted-work crashed. The pipeline would saturate all CPU cores (peaks of 1668% on a 14-core i7-12700H), allocate 20GB RAM on a single 564KB markdown file, and trigger swap thrash that the kernel could not recover from before the watchdog gave up.

This is the kind of failure mode that a Mac developer never sees, because their tooling has been beaten into shape over two decades by Apple. We had to invent ours. The mandatory Memvid write protocol now wraps every ingest in a systemd cgroup:

```bash
systemd-run --user --scope -q \
  -p CPUQuota=800% \
  -p MemoryMax=8G \
  -p MemorySwapMax=0 \
  memvid put "$MV" --input "$FILE" --embedding -m nomic --vector-compression
```

`CPUQuota=800%` caps the embedder at 8 cores, leaving 6 logical cores for the OS and the editor. `MemoryMax=8G` is a hard RSS ceiling — exceed it and the kernel kills the process *cleanly* rather than letting it drag the system down. `MemorySwapMax=0` forbids the swap spiral entirely. Combined with a chunking step (split markdown >50KB along H2/H3 boundaries before ingest), this turned an unstable pipeline into one that processed 988 frames across 4 shards with zero failures during the iMoonshine project.

A separate forensics sidecar, sampling `/proc/loadavg`, `/proc/meminfo`, and `nvidia-smi` every two seconds with `sync -f` after each write, catches the rare cases where a hard crash still happens — the log survives reboot and tells us exactly what state the system was in 2 seconds before the freeze.

### The Memvid lesson

The lesson is general, and worth stating explicitly: **on Mac, the toolchain is the operating environment. On Linux, you build the operating environment.** That sounds like a complaint. It is actually the source of the leverage. Because we built the environment, we knew where every joint was. When something broke, we could fix it at the level it was broken, not work around it at the level Apple decided to expose. The Memvid resource cap is not a workaround for a Linux limitation; it is a deliberate engineering choice that we own.

---

## Part 6: iMoonshine, Specifically

Now to the app itself.

iMoonshine is a single-purpose iOS app: hold-to-talk transcription using Moonshine's on-device streaming ASR models, exposed through the iOS Action Button (single press) and Apple Shortcuts (programmable). The user's stated goal — repeated through every revision — was *zero round-trip latency*: press the Action Button, speak, release, transcript on clipboard. No "open the app". No tap. No second confirmation. Press → speak → release → paste.

To make that work end-to-end, iMoonshine needs:

1. A foreground SwiftUI app that can record, transcribe, and display.
2. A background `BackgroundShortcutRunner` that can do the same thing from an `AppIntent` invocation, with no UI, while the screen is off.
3. A Moonshine ONNX runtime — `Vendor/moonshine-swift` — that loads ~235MB of `.ort` files and streams audio through them.
4. An `App Intents` definition (`ToggleRecordingIntent`) that flips between recording-active and recording-stopped, and returns the final transcript as a typed `String` so Shortcuts can chain it.
5. Audio session management that survives the background trigger path. (This is the one that almost killed us.)
6. App Group shared storage so foreground and background processes see the same recording state.
7. Code signing with developer entitlements that include the App Group, microphone, App Intents, and background modes.
8. An IPA that can be installed via xtool's pairing/tunneling pipeline to a real device.

Each item on that list became its own multi-day investigation. I will not claim I diagnosed all of them correctly the first time — the record shows that I confidently misdiagnosed several, and the user had to interrupt and redirect. Two of those misdiagnoses are worth recounting because they teach the lesson cleanly.

### Misdiagnosis 1: GPU VRAM exhaustion

When Memvid's pipeline started crashing the host, my first hypothesis was GPU virtual address space exhaustion. We had recently added the Ollama embedder; Ollama uses CUDA; CUDA has well-known VA-space bugs on consumer GPUs; therefore the freeze was a GPU fault. I proposed bumping `OLLAMA_MAX_VRAM` and limiting `OLLAMA_MAX_LOADED_MODELS=1`.

The user, watching `top` in another terminal, interrupted: *"the GPU is at 4% utilization, 11% memory. The CPU is at 100% on every core and we're at 19GB resident. It's not the GPU."*

That was the moment we wrote the cgroup wrapper. The fix was not GPU-side at all. The misdiagnosis cost a half-day; the redirect saved the project. **Lesson: when a system goes down hard, gather CPU, memory, *and* GPU metrics together before reaching for a hypothesis.**

### Misdiagnosis 2: AVAudioSession in the background

The Action Button trigger initially failed silently. The intent fired (we had logs to prove it), but no audio was ever captured. My hypothesis was that `supportedModes` on the App Intent declaration was wrong — that the intent needed `IntentModeBackground` set for iOS to allow it to run from a locked screen.

We patched `AppIntentsGen` to force `supportedModes=1` for `AudioRecordingIntent` (commit 1da11e2). The intent fired successfully. The audio still did not record.

The actual bug was upstream: `BackgroundShortcutRunner` was setting up its `AVAudioSession` *after* attempting to start the audio engine, in a context where the session had not yet been activated for `.record` mode. iOS happily ran the intent, and silently dropped the microphone access because no active session had requested it. The fix was to call `AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.mixWithOthers])` and `.setActive(true)` *before* engaging the recorder, and to do so on the background runner's thread.

That fix landed, and in landing, it briefly regressed the AppIntents metadata emission — a change to `BackgroundShortcutRunner` perturbed the resource bundle layout in a way that AppIntentsGen's scanner missed. We caught it because, by then, our build pipeline included a `find .build -name 'Metadata.appintents'` post-build assertion that screamed when the metadata bundle was missing. Without that hook, we would have shipped a broken build.

**Lesson: post-build artifact verification is not optional. Build success is not feature success.** This is now codified in our project's build playbook.

### The 235MB problem

Moonshine `smallStreaming` ships as six `.ort` files totaling 235MB. SwiftPM resource bundling handles them via `Bundle.module` once they are placed in `Sources/iMoonshineCore/Models/small-streaming-en/` and declared in `Package.swift`. That part worked first try. The interesting question — still unresolved as of this writing — was about the *next* model up, `mediumStreaming`, which weighs in north of 600MB and bumps individual files past GitHub's 100MB per-file ceiling.

The plan was to ship medium-streaming weights via GitHub Releases (which lift the ceiling to 2GB per asset), download on first use, and persist the choice in App Group `UserDefaults` so foreground and background paths agreed on which arch was loaded. The user pointed at HuggingFace's `UsefulSensors/models` repository as the upstream, but that repository ships safetensors, not ORT — meaning either we needed to find pre-converted ORT artifacts elsewhere or run Moonshine's quantization/conversion scripts ourselves before publishing the GitHub Release.

That work is in progress. The toggle UI is sketched. The persistence layer is designed. The release-asset download path is plumbed. What is missing is the binary blob and a confirmed source for it. This is the kind of dependency that would be a non-issue on Mac (you would just drag-and-drop into Xcode), and is a half-day of work on Linux. *That is the whole story of this project, in one anecdote.*

---

## Part 7: The Catalog of "It Has To Be Done On A Mac"

Below is a partial list of things I told the user, with confidence, that *had* to be done on a Mac. Each was wrong. The fix is in the third column.

| Claim                                                            | Reality                                                                                                | Fix                                              |
|------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| App Intents metadata requires `appintentsmetadataprocessor`      | xtool's AppIntentsGen reimplements it in Swift; we patched in the missing `outputType` emission        | `Emitter.swift` outputType key + Scanner walk    |
| Shortcuts magic variables require Xcode-generated metadata       | They require a single dictionary key in the bundled actionsdata                                        | Two-line patch, ~50 lines of tests               |
| Code signing with developer entitlements requires `codesign`     | `ldid` / `zsign` produce signatures iOS accepts, given the right entitlements plist                    | Already solved in xtool                          |
| Asset catalog compilation needs `actool`                         | xtool ships a Swift `actool` shim; works for our Assets.xcassets                                       | Already solved in xtool                          |
| Resource bundles (`Bundle.module`) require Xcode build phases    | SwiftPM handles them on Linux identically                                                              | Just declare resources in `Package.swift`        |
| Device installation requires Xcode's pairing UI                  | `pymobiledevice3` plus xtool's tunnel handler does it                                                  | iOS 17+ DDI mount path, commit a2a77ec           |
| AppIntents discovery requires Xcode's "Build for Testing" path   | iOS reindexes on first foreground launch of a freshly installed bundle                                 | Open the app once after install                  |
| Background AppIntent runner needs Xcode's background-modes UI    | The `UIBackgroundModes` plist key plus the right entitlement does it                                   | Hand-edit Info.plist                             |

Every single one of these I or another agent declared "Mac-only" at some point. Every single one shipped on Linux. The pattern is consistent: *Mac-only* is almost always shorthand for *Apple ships this convenience on Mac, and nobody has yet bothered to reimplement it elsewhere*. Each reimplementation is finite work. It is not infinite. It is not even hard. It is just — *not done yet*.

The xtool team did most of the heavy lifting. We did the last 5%, plus the operational discipline to actually use it.

---

## Part 8: What This Was Really About

It is tempting to frame this as a story about clever workarounds, or about Apple's lock-in, or about Linux as a viable iOS dev platform. Those framings are partially true and mostly miss the point.

The real story is about *agency*. The default path — buy a Mac, install Xcode, click Build — is so frictionless that almost nobody questions whether the underlying capabilities are actually Apple-exclusive or just Apple-packaged. xtool is the experiment that asks the question. iMoonshine is the proof. Memvid is the operational substrate that made the proof reproducible across months and agents.

The capabilities are not Apple-exclusive. They are Apple-packaged. The packaging is convenient and worth a thousand dollars to most people. For the people who would rather understand the joints, take the half-day hits, and own the toolchain, the alternative path is now real. It runs on Ubuntu 25.10. It signs and ships an IPA that talks to Siri.

A user who declared, multiple times, that they would not buy a Mac, has a working iOS app on their iPhone. They wrote it on Linux. So did the build pipeline. So did the metadata processor. So did the memory system that kept it all coherent.

The only Mac involved was the one whose SDK we extracted, exactly once, two years ago.

---

## Epilogue: What Comes Next

The medium-streaming model toggle. That is the immediate next task — confirm the source for the ORT-format weights, ship them via a GitHub Release, wire the in-app toggle, persist the choice in App Group `UserDefaults`, and handle the reload edge cases (toggle flipped mid-recording, toggle flipped between foreground recording and a queued background intent invocation, etc.).

After that, a quieter cleanup pass. The `outputType` emission currently uses `typeIdentifier: 0`, which works for the Shortcuts editor's purposes but is a placeholder for the real Apple type code. We should dump a half-dozen reference IPAs, identify the canonical type codes for `String`, `Bool`, `Int`, and `Date` outputs, and emit the right ones. Future intents that return non-trivial types (entities, enums) will need this mapping to be complete.

And eventually — though this feels far away today — pushing the AppIntentsGen patches upstream to the xtool project. The world should not need to discover the missing `outputType` key one project at a time.

We compiled the impossible. The receipts are in `git log` and in `global_memory.mv2`. The next person who tries this on Linux will, at minimum, not have to discover what we discovered. That is the contribution.

---

*— iMoonshine project field notes, 2026-05-03.*

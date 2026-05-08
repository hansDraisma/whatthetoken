# Menu Bar Chrome Actions Activation Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the popover overflow menu's Settings and About items so they actually open / show in `.accessory` activation mode. Today, clicking "Settings…" does nothing and "About WhatTheToken" can render behind other windows.

**Architecture:** A narrow chrome-action helper plus two call-site changes across `WhatTheTokenApp.swift` and `Views/Popover/PopoverFooterView.swift`. Adopt SwiftUI's macOS 14 `@Environment(\.openSettings)` for the Settings flow (canonical, avoids string selectors), and activate the app *before* dispatching the action in **all three** affected paths: Settings, About, and (DEBUG) Open Developer Window. Quit is unaffected — `terminate(nil)` works regardless of activation state.

**Tech Stack:** Swift 6.0, SwiftUI (`@Environment(\.openSettings)`, `Settings { … }` scene), AppKit interop (`NSApplication.shared.activate(ignoringOtherApps:)`, `orderFrontStandardAboutPanel`).

---

## Why This Plan Is Needed

Currently `WhatTheTokenApp.swift:42-51`:

```swift
private func openSettings() {
    if #available(macOS 14, *) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    NSApplication.shared.activate(ignoringOtherApps: true)
}
```

In `.accessory` mode the app is not frontmost when the user clicks the menu-bar popover. `NSApp.sendAction(_:to:from:)` with `to: nil` walks the responder chain of the *currently active* app — not ours — so the action goes nowhere. Activating *after* doesn't help; the action has already been dispatched into the void.

The same issue affects the About panel: `NSApplication.shared.orderFrontStandardAboutPanel(nil)` shows a panel, but without prior activation the panel may render behind whatever app was previously frontmost.

This plan fixes both by activating first and switching Settings to the SwiftUI-blessed `@Environment(\.openSettings)` API.

---

## File Structure

```
apps/mac/Sources/WhatTheTokenMac/
  MacChromeActions.swift                             # ADD (Task 1)
  WhatTheTokenApp.swift                              # MODIFY (Task 1)
  Views/
    Popover/
      PopoverFooterView.swift                        # MODIFY (Task 2)
apps/mac/Tests/WhatTheTokenMacTests/
  Presentation/
    MacChromeActionTests.swift                       # ADD (Task 1)
```

The live SwiftUI scene presentation still needs manual smoke coverage, but the ordering contract is unit-tested with injectable closures so Settings, About, and Developer Window cannot regress to action-before-activation silently.

---

## Conventions

**Test command (full):** `cd apps/mac && swift test`
**Build command:** `cd apps/mac && swift build`
**Run command:** `cd apps/mac && swift run WhatTheTokenMac`
**Commit style:** `fix(mac): …` for bug fixes.
**Branch:** Stay on the current branch (`hansDraisma/menubar-spend-tabs`).

---

## Task 1: Adopt `@Environment(\.openSettings)` and activate before opening Settings

**Files:**
- Add: `apps/mac/Sources/WhatTheTokenMac/MacChromeActions.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`
- Add: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/MacChromeActionTests.swift`

- [ ] **Step 1: Read the current `WhatTheTokenApp.swift`**

```
cd apps/mac && cat Sources/WhatTheTokenMac/WhatTheTokenApp.swift
```

Confirm the current `openSettings()` has the (action-then-activate) order. The fix replaces the entire helper.

- [ ] **Step 2: Add focused ordering tests**

Add `apps/mac/Tests/WhatTheTokenMacTests/Presentation/MacChromeActionTests.swift` with tests for:

- Settings: records `["activate", "openSettings"]`.
- About: records `["activate", "showAbout"]`.
- Developer Window: records `["activate", "openWindow"]`.

Run the focused tests before adding the helper:

```
cd apps/mac && swift test --filter MacChromeActionTests
```

Expected before implementation: fails because `MacChromeActions` does not exist.

- [ ] **Step 3: Add the shared chrome-action helper**

Create `apps/mac/Sources/WhatTheTokenMac/MacChromeActions.swift`:

```swift
#if canImport(AppKit)
import AppKit
#endif

enum MacChromeActions {
    @MainActor
    static func openSettings(
        activate: @MainActor () -> Void = defaultActivate,
        openSettings: @MainActor () -> Void
    ) {
        activate()
        openSettings()
    }

    @MainActor
    static func showAbout(
        activate: @MainActor () -> Void = defaultActivate,
        showAbout: @MainActor () -> Void = defaultShowAbout
    ) {
        activate()
        showAbout()
    }

    @MainActor
    static func openDeveloperWindow(
        activate: @MainActor () -> Void = defaultActivate,
        openWindow: @MainActor () -> Void
    ) {
        activate()
        openWindow()
    }

    @MainActor
    private static func defaultActivate() {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    @MainActor
    private static func defaultShowAbout() {
        #if canImport(AppKit)
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        #endif
    }
}
```

- [ ] **Step 4: Replace the App's `openSettings()` plumbing**

Edit `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift` so the App holds the SwiftUI environment value and calls it after activating. Replace the existing struct body and helper with:

```swift
import SwiftUI

@main
struct WhatTheTokenApp: App {
    private let app: AppModel = .live()

    @Environment(\.openWindow)   private var openWindow
    @Environment(\.openSettings) private var openSettingsScene

    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        if CodexConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            CodexConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        MacAppLauncher.configureLaunch()
    }

    var body: some Scene {
        MenuBarExtra("WhatTheToken", systemImage: "gauge") {
            PopoverRootView(
                viewModel: app.viewModel,
                controller: app.refreshController,
                onOpenSettings: openSettingsAction,
                onOpenDeveloperWindow: developerWindowOpener
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView(viewModel: app.viewModel)
        }

        #if DEBUG
        Window("WhatTheToken - Developer", id: "developer") {
            DeveloperWindowView(viewModel: app.viewModel)
        }
        #endif
    }

    /// Activate first so the responder chain has a frontmost app, then ask
    /// SwiftUI to open the Settings scene. The previous `NSApp.sendAction`
    /// approach dispatched into nothing because `.accessory` apps are not
    /// frontmost when the menu-bar popover is shown.
    private func openSettingsAction() {
        MacChromeActions.openSettings {
            openSettingsScene()
        }
    }

    private var developerWindowOpener: (() -> Void)? {
        #if DEBUG
        let openWindow = self.openWindow
        return {
            MacChromeActions.openDeveloperWindow {
                openWindow(id: "developer")
            }
        }
        #else
        return nil
        #endif
    }
}
```

The old `private func openSettings()` is removed entirely. The `PopoverRootView` call site now passes `openSettingsAction` (the new helper) — the parameter name `onOpenSettings` is unchanged so no upstream change is needed. The `developerWindowOpener` mirrors the activate-then-open pattern via `MacChromeActions`.

- [ ] **Step 5: Build to confirm no regressions**

```
cd apps/mac && swift build
```

Expected: clean build. If the build fails because `\.openSettings` is missing, double-check macOS deployment target is `.macOS(.v14)` in `Package.swift` (it is — `@Environment(\.openSettings)` is macOS 14+).

- [ ] **Step 6: Run the focused and full unit-test suites**

```
cd apps/mac && swift test --filter MacChromeActionTests
```

Expected: the three ordering tests pass.

```
cd apps/mac && swift test
```

Expected: all tests pass.

- [ ] **Step 7: Manual smoke — Settings opens**

```
cd apps/mac && swift run WhatTheTokenMac
```

Then in the running app:
1. Click the menu-bar gauge icon → popover opens.
2. Click `•••` → menu opens.
3. Click `Settings…` → the Settings window opens **and is frontmost** (you can interact with it, it accepts keyboard focus).
4. Close the Settings window.
5. Repeat 1–3 → opens reliably each time.

If the window opens but is behind another app, the activation step is being skipped — re-check that the `NSApplication.shared.activate(...)` call comes *before* `openSettingsScene()`.

- [ ] **Step 8: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift
git commit -m "fix(mac): activate before opening Settings scene"
```

---

## Task 2: Activate before showing the standard About panel

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`

The About item is currently inline in `PopoverFooterView`'s overflow menu and calls `NSApplication.shared.orderFrontStandardAboutPanel(nil)` directly. Same activation-order issue: the panel shows but may render behind another app.

- [ ] **Step 1: Update the About menu item**

Edit `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`. Replace the existing `Menu { … }` block (the overflow menu) with:

```swift
            Menu {
                Button("Settings...", action: onOpenSettings)
                Button("About WhatTheToken") {
                    // Activate before showing the panel so it comes to front
                    // in `.accessory` mode (where the app is not frontmost
                    // when the menu-bar popover is shown).
                    MacChromeActions.showAbout()
                }
                #if DEBUG
                if let onOpenDeveloperWindow {
                    Button("Open Developer Window", action: onOpenDeveloperWindow)
                }
                #endif
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
```

The only change inside the `Menu { }` is the About button's action body: delegate to `MacChromeActions.showAbout()`, which activates before `orderFrontStandardAboutPanel`. Settings, Developer Window, and Quit remain untouched.

- [ ] **Step 2: Build**

```
cd apps/mac && swift build
```

Expected: clean.

- [ ] **Step 3: Manual smoke — About panel comes to front**

```
cd apps/mac && swift run WhatTheTokenMac
```

1. Make some other app frontmost (a Finder window, a browser).
2. Click the menu-bar gauge icon → popover opens.
3. Click `•••` → menu opens.
4. Click `About WhatTheToken` → the standard About panel appears **on top** of the previously-frontmost app. You can move/close it.
5. Close the About panel.
6. Repeat with the popover open over a fullscreen app to confirm.

- [ ] **Step 4: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift
git commit -m "fix(mac): activate app before showing About panel"
```

---

## Final Manual Smoke (combined)

After both tasks, walk the chrome-actions checklist end-to-end:

1. Launch via `swift run WhatTheTokenMac`. No Dock icon. Menu-bar gauge appears.
2. Click menu-bar icon → popover opens.
3. `•••` → `Settings…` → Settings window opens, frontmost.
4. Close Settings. Click menu-bar icon, `•••` → `About WhatTheToken` → About panel opens, frontmost.
5. Close About. `•••` → `Quit` → app terminates cleanly.
6. (DEBUG build only) After relaunch, `•••` → `Open Developer Window` → developer window opens, frontmost.

Report any step that doesn't work — those are bugs that escape this fix and need their own follow-ups.

---

## Out of Scope

- **Cmd+, keyboard shortcut.** In `.accessory` mode the system menu bar is not constructed, so `Cmd+,` cannot be wired up the standard way. If we need this shortcut, the follow-up is to register a `KeyboardShortcut` on the popover's `•••` Settings item (which only fires while the popover is open) or move to a non-`.accessory` activation policy. Neither is in scope for this fix.
- **Activation-policy refactor.** The `.accessory` policy itself is intentional and remains the right call for a menu-bar utility. Not changing.
- **Full SwiftUI scene presentation tests.** The action ordering is unit-tested, but actually presenting Settings/About/Developer Window still needs the manual smoke checklist above because this codebase does not have SwiftUI scene-inspection coverage.

---

## Self-Review Checklist

- **Spec coverage:** This plan does not change any spec invariant. The behavior fixed here was implicit in the existing spec — Settings and About menu items must function. The plan adds the missing wiring detail.
- **Placeholder scan:** No TBDs / TODOs / "implement later".
- **Type consistency:** `openSettingsAction` matches the `onOpenSettings: () -> Void` parameter on `PopoverRootView`. `\.openSettings` requires macOS 14, which is the package's deployment target.
- **Test coverage:** `MacChromeActionTests` verifies activation happens before each chrome action; manual smoke verifies real macOS scene/panel presentation.
- **Bug fix only:** No new features, no scope expansion.

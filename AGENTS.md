# Agent guidance

This is a native macOS SwiftUI app. Before UI or Swift work, use the installed `apple-design`, `emil-design-eng`, and `write-swift` skills together.

- Preserve the Make target contract. Keep build details in `Scripts/`, not duplicated in `Makefile`.
- Use system macOS patterns and controls before inventing custom components. Support menus, keyboard navigation, resizing, semantic colors, accessibility, and reduced motion.
- Keep the application main-actor isolated by default. Prefer value types and concrete models. Add concurrency only for measured work or real latency.
- Add Swift Testing coverage for model and behavior changes.
- Run `make agent-check` before handoff. For visible work, inspect the running app in light/dark appearance and at multiple window sizes; report visual checks separately.
- Do not change the bundle identifier, entitlements, signing, or installation behavior incidentally.
- Once the app keeps user data, never launch a development build on the real store: add `make sandbox` (see the `macos-app` skill's `references/sandbox.md`) and use it.
- `make icon` needs [glasur](https://github.com/geisterzeit/glasur) on the `PATH`; builds only need it while `Resources/AppIcon.icon` does not exist yet.

## Feierabend specifics

- One executable, three roles (`LaunchRole`). Launched by Bambu Studio with a G-code path as its last argument, it acts as a relay: it relaunches itself through LaunchServices with `--scheduler`, because a plain child process can't take keyboard focus from Bambu Studio, and waits for that instance to quit. The scheduler instance shows the window and rewrites the G-code in place. Any other launch shows the setup window.
- The app is not sandboxed on purpose: it must rewrite G-code files in Bambu Studio's temporary folders.
- It keeps no user data besides the last chosen schedule in `UserDefaults`, so `make run` and `make try-hook` are safe to launch. `make try-hook` runs the scheduler on a copy of `Scripts/Fixtures/sample-plate.gcode` in `build/`.

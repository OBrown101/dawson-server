# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common commands

| Purpose | Command | Notes |
|---------|---------|-------|
| Build the project | `swift build` | Builds in debug mode; binary in `.build/debug`. |
| Build release binary | `swift build -c release` | Binary in `.build/release`. |
| Clean artifacts | `swift package clean` | Removes `.build` directory. |
| Run the server | `swift run` | Starts the Vapor server defined in `Sources/classes/main.swift`. |
| Run tests | `swift test` | Executes any Swift test targets (none currently). |
| Run TTS helper | `source python/venv/bin/activate && python python/piper_wrapper.py` | Requires the Python virtual‑environment. |

## High‑level architecture

* **Core runtime** – A Swift 6 Vapor server (`Sources/classes/main.swift`). It sets up a WebSocket at `/dawson`, forwards messages to a `DAWSON` instance, and manages the agent logic via `Agent.swift`.
* **Agent subsystem** – `Agent.swift` implements the LLM‑driven agent, handling conversation state, tool execution, and streaming responses. It interacts with the memory engine and Python bridge.
* **Memory engine** – `MempalaceMemory.swift` stores knowledge using SQLite and embeddings located under `.mempalace`.
* **Python bridge** – `PythonHandler.swift` launches Python scripts through `PythonKit`. The scripts live in `python/mempalace_handler.py` and provide protocol support for the agent.
* **Text‑to‑speech** – `TTS/piper_wrapper.py` can be invoked to generate spoken responses; it relies on the Piper TTS engine.
* **Package configuration** – `Package.swift` declares dependencies (`Vapor`, `PythonKit`, etc.) and targets. `entities.json` and `mempalace.yaml` hold schema and runtime settings.

These components together provide a chatbot‑style application that processes user messages via an LLM, uses tools, persists context, and optionally outputs speech.
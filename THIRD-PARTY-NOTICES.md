# Third-Party Notices

DAWSON incorporates or interoperates with the following third-party
software. Each component remains under its own license, reproduced or
referenced below. These licenses apply only to the components listed;
DAWSON itself is licensed as described in `LICENSE`.

> Maintenance note: keep this file in sync with what the release
> artifacts actually bundle. If a component is downloaded at install
> time rather than shipped in the artifact, it may be listed as
> "installed separately" instead.

---

## MemPalace

- Source: https://github.com/MemPalace/mempalace
- License: MIT
- Usage: memory backend, accessed via its MCP stdio server

```
MIT License

Copyright (c) 2026 MemPalace Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```


---

## ChromaDB

- Source: https://github.com/chroma-core/chroma
- License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)
- Usage: default vector store backend used by MemPalace

## all-MiniLM-L6-v2 (ONNX embedding model)

- Source: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- License: Apache License 2.0
- Usage: local embedding model cached for semantic search

## CPython (bundled Python runtime, if shipped)

- Source: https://www.python.org
- License: Python Software Foundation License Version 2
  (https://docs.python.org/3/license.html)
- Usage: embedded interpreter for MemPalace and Python tooling

## Vapor and Swift package dependencies

The DAWSON server links Swift packages resolved in `Package.resolved`
(Vapor and its dependencies, MIT licensed, among others). Run
`swift package show-dependencies` against a release tag for the full
tree, and include each package's license file in binary distributions.

#!/usr/bin/env python3
import sys
import json
from mempalace.searcher import search_memories

memory = MemoryPalace(persist_directory="./mempalace_data")

def handle_get_context(data):
    query = data.get("query", "")
    results = memory.mine(query, top_k=5)

    messages = []
    for r in results:
        messages.append({
            "role": "system",
            "content": r["text"]
        })

    return {"messages": messages}


def handle_store(data):
    text = data.get("text", "")
    metadata = data.get("metadata", {})

    memory.add(text, metadata=metadata)
    return {"status": "ok"}


def main():
    for line in sys.stdin:
        try:
            data = json.loads(line)
            action = data.get("action")

            if action == "get_context":
                result = handle_get_context(data)
            elif action == "store":
                result = handle_store(data)
            else:
                result = {"error": "unknown action"}

            print(json.dumps(result))
            sys.stdout.flush()

        except Exception as e:
            print(json.dumps({"error": str(e)}))
            sys.stdout.flush()


if __name__ == "__main__":
    main()

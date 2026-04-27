#!/usr/bin/env python3
import os
from mempalace.searcher import search_memories
from mempalace.layers import MemoryStack
from python_handler import PythonHandler


class MempalaceHandler(PythonHandler):
    def search_memories(self, params: dict) -> dict:
        query = params.get("query", "")
        palace_path = params.get("palace_path", "~/.mempalace/palace")
        wing = params.get("wing")
        room = params.get("room")
        n_results = params.get("n_results", 5)

        results = search_memories(
            query=query,
            palace_path=palace_path,
            wing=wing,
            room=room,
            n_results=n_results
        )
        
        return results
        
    def wake_up(self, params: dict) -> dict:
        stack = MemoryStack()
        return {"text": stack.wake_up()}
        
    def status(self, params: dict) -> dict:
        stack = MemoryStack()
        return {"text": stack.status()}

if __name__ == "__main__":
    MempalaceHandler().run()

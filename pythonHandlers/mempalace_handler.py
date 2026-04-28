#!/usr/bin/env python3
import os
from python_handler import PythonHandler
from mempalace.mcp_server import handle_request
import datetime


class MempalaceHandler(PythonHandler):

    def mcp_wrapper(self, params: dict) -> dict:
        try:
            result = handle_request(params)
            return result if result is not None else {}
        except Exception as e:
            return {"error": f"handle_request failed: {e}"}


if __name__ == "__main__":
    MempalaceHandler().run()

#!/usr/bin/env python3
import sys
import json
from abc import ABC

class PythonHandler(ABC):
    def run(self):
        try:
            input_data = self.read_input()

            self.write_output({"debug": "step1"})

            method_name = input_data.get("method")
            params = input_data.get("params", {})

            if not method_name:
                raise ValueError("No method provided")

            if not hasattr(self, method_name):
                raise ValueError(f"Unknown method: {method_name}")

            method = getattr(self, method_name)

            if not callable(method):
                raise ValueError(f"Method not callable: {method_name}")

            self.write_output({"debug": "step2"})

            result = method(params)

            self.write_output({
                "method": method_name,
                "result": result
            })

        except Exception as e:
            self.write_output({
                "error": f"Python handler execution failed: {e}"
            })

    def read_input(self) -> dict:
        raw = sys.stdin.read().strip()

        if not raw:
            return {}

        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            raise ValueError("Invalid JSON input received from Swift.")

    def write_output(self, output: dict):
        print(json.dumps(output))

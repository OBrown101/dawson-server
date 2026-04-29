#!/usr/bin/env python3
import os
from mempalace.mcp_server import handle_request
import datetime

def mcp_wrapper(params: dict):
    try:
        return handle_request(params) or {}
    except Exception as e:
        return {"error": str(e)}

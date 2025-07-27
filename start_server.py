#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API サーバー起動スクリプト
"""

import uvicorn

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8082, reload=False)
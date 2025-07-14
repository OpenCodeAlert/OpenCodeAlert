#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试Ping功能的简单脚本
"""

import time
from OpenRA_Copilot_Library.game_api import GameAPI

def test_ping():
    """测试服务器ping功能"""
    print("开始测试ping功能~")
    
    # 检查服务器是否运行
    print("检查服务器状态...")
    is_running = GameAPI.is_server_running(host="localhost", port=7446)
    
    if is_running:
        print("✅ 服务器运行中！可以连接喵~")
        
        # 连接服务器并获取更详细信息
        try:
            api = GameAPI("localhost", 7446)
            response = api._send_request('ping', {})
            print(f"服务器详细信息: {response['data']}")
            print(f"API版本: {response['data']['version']}")
            print(f"时间戳: {response['data']['timestamp']}")
            print("✅ Ping测试成功！服务器响应正常喵~")
        except Exception as e:
            print(f"❌ 连接服务器失败: {e}")
    else:
        print("❌ 服务器未运行或无法访问，请先启动游戏客户端喵...")
    
    print("测试完成~")

if __name__ == "__main__":
    test_ping() 
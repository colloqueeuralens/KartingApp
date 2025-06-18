#!/usr/bin/env python3
import asyncio
import websockets
import json

async def test_websocket():
    uri = "ws://172.25.147.11:8001/circuits/vRHwx826i4wRXMGpRzVY/live"
    print(f"Connecting to: {uri}")
    
    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected to WebSocket!")
            
            # Send a ping
            ping_message = json.dumps({"type": "ping"})
            await websocket.send(ping_message)
            print(f"📤 Sent: {ping_message}")
            
            # Wait for response
            response = await websocket.recv()
            print(f"📥 Received: {response}")
            
            # Keep connection alive for a few seconds
            await asyncio.sleep(3)
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_websocket())
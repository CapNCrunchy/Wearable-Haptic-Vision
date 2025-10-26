import asyncio, struct, json
import websockets
import numpy as np
from PIL import Image
from io import BytesIO

async def handler(ws):
    print("connected")
    async for msg in ws:
        if isinstance(msg, bytes):
            if len(msg) < 4: continue
            (hdr_len,) = struct.unpack("<I", msg[:4])
            hdr_json = msg[4:4+hdr_len]
            png_bytes = msg[4+hdr_len:]
            header = json.loads(hdr_json.decode("utf-8"))
            
            img = Image.open(BytesIO(png_bytes))
            depth_u16 = np.array(img, dtype=np.uint16)
            scale = header.get("scale_m_per_unit", 0.001)
            depth_m = depth_u16.astype(np.float32) * scale

            fx, fy, cx, cy = header["fx"], header["fy"], header["cx"], header["cy"]
            pose = np.array(header["pose_4x4_row_major"], dtype=np.float32).reshape(4,4)
            
            h, w = depth_m.shape
            crop = depth_m[h//3:2*h//3, w//3:2*w//3]
            min_m = float(np.nanmin(crop[crop > 0])) if np.any(crop > 0) else 999.0
            cmd = {"type": "cmd", "stop": (min_m < 0.8), "min_m": round(min_m, 2)}
            await ws.send(json.dumps(cmd))
        else:
            print("text:", msg)

async def main():
    async with websockets.serve(handler, "0.0.0.0", 8765, max_size=None, ping_interval=20):
        print("listening on :8765")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())

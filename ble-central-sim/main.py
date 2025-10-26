import asyncio
from bleak import BleakClient, BleakScanner
import random
import struct

async def write_data(client, writable_char):
    while True:
        data = random.random()
        data_bytes = struct.pack('f', data)
        
        await client.write_gatt_char(writable_char.uuid, data_bytes)
        print(f"Data written successfully! Value: {data}")
        
        await asyncio.sleep(5)

async def main():
    service_uuid = "8b322909-2d3b-447b-a4d5-dfe0c009ec5a"

    devices = await BleakScanner.discover(service_uuids=[service_uuid])

    for d in devices:
        print(f"{d.name}: {d.address}")

    if devices:
        device_address = devices[0].address

        async with BleakClient(device_address) as client:
            print(f"Connected: {client.is_connected}")

            writable_char = None
            for service in client.services:
                for char in service.characteristics:
                    if "write" in char.properties or "write-without-response" in char.properties:
                        writable_char = char
                        print(f"Found writable characteristic: {char.uuid}")
                        print(f"  Service: {service.uuid}")
                        print(f"  Properties: {char.properties}")
                        break
                if writable_char:
                    break

            if writable_char:
                await write_data(client, writable_char)
            else:
                print("No writable characteristic found!")

asyncio.run(main())
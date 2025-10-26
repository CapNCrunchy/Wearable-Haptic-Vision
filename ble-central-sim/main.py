import asyncio
from bleak import BleakClient, BleakScanner

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
                data = bytes([0x01, 0x02, 0x03])
                await client.write_gatt_char(writable_char.uuid, data)
                print("Data written successfully!")
            else:
                print("No writable characteristic found!")

asyncio.run(main()) 
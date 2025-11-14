#the code that runs on the Feather rp2040
''' code for the pi
import serial
import time

ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
time.sleep(2)

# Example 6-byte message
msg = bytes([10, 20, 30, 40, 50, 60])

ser.write(msg)
ser.close()

'''
import usb_cdc
import time
import board
import digitalio

# nodeN_n where N is the node number and n is the valve number. 
# 1 and 2 are binary valves where binary number XX is valve "21"
# eg if valve 2 is high and valve 1 is low the binary state is 0b10 or 2 

AllNodesOn = digitalio.DigitalInOut(board.D4)
AllNodesOn.direction = digitalio.Direction.OUTPUT

Node1_1 = digitalio.DigitalInOut(board.D13)
Node1_1.direction = digitalio.Direction.OUTPUT
Node1_2 = digitalio.DigitalInOut(board.D12)
Node1_2.direction = digitalio.Direction.OUTPUT

Node2_1 = digitalio.DigitalInOut(board.D11)
Node2_1.direction = digitalio.Direction.OUTPUT
Node2_2 = digitalio.DigitalInOut(board.D10)
Node2_2.direction = digitalio.Direction.OUTPUT

Node3_1 = digitalio.DigitalInOut(board.D9)
Node3_1.direction = digitalio.Direction.OUTPUT
Node3_2 = digitalio.DigitalInOut(board.D6)
Node3_2.direction = digitalio.Direction.OUTPUT

Node4_1 = digitalio.DigitalInOut(board.D5)
Node4_1.direction = digitalio.Direction.OUTPUT
Node4_2 = digitalio.DigitalInOut(board.D25)
Node4_2.direction = digitalio.Direction.OUTPUT

Node5_1 = digitalio.DigitalInOut(board.SCK) #these ones and down are still GPIO but have other functions
Node5_1.direction = digitalio.Direction.OUTPUT
Node5_2 = digitalio.DigitalInOut(board.MOSI)
Node5_2.direction = digitalio.Direction.OUTPUT

Node6_1 = digitalio.DigitalInOut(board.MISO)
Node6_1.direction = digitalio.Direction.OUTPUT
Node6_2 = digitalio.DigitalInOut(board.RX)
Node6_2.direction = digitalio.Direction.OUTPUT


# Use the "data" serial channel
serial = usb_cdc.data
NodeStates = bytearray(6)
while True:
    if serial.in_waiting >= 6: #sending the 6 bytes that correspond to the 6 node states (1-4)
        serial.readinto(NodeStates)
    
    AllNodesOn.value = True
    #gonna loop through and parse the bytearray for each value and then assign each node accordingly
    


    #turn on every node 
    
    time.sleep(0.01)

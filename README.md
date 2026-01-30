# Wearable-Haptic-Vision
Capstone project for UF CpE

# Project Architecture
"Wearable Haptic Vision" is a device that uses a wearable tactile display to inform the wearer about their surroundings by receiving object distance information. It will capture LiDAR depth information and utilize a Raspberry controller unit to make the wearable pressure waistband react according to an object's distance and direction.

## Pressure Waistband
The waistband will have embedded inflatable nodes that each have tubing connecting to a main housing unit that will hold the intake/exhaust controls (logic circuitry, pressure sensors, raspberry pi). There are 8 nodes that go across the waist and each will inflate according to the corresponding lidar information. For example, if an object is very close to the right side of the Lidar then the nodes on the right side will inflate to the max to represent the closest object. The inverse is also true that an object that is far away will be represented by a very deflated node.

## LiDAR Application
It is an iOS swift application taht utilizes the iphone built in LiDAR to retrieve location and distance information. It takes it as a full image map and then averages the values within the corresponding divisions. This is sent to the Raspberry Pi controller via BLE.

## Controller
The Raspberry Pi takes the lidar data and simplifies it into four states by distance. It then sends this data to the pressure regulator logic which switches between intake and exhaust to get to the correct state. This gives each node four distance/pressure states. 

# Completed Work 
- BLE reciever and Swift application connection
- Infalte/deflate valves for nodes
- Inflate/deflate Schematics w/ Rasperbery pi & modules
- Swift IOS application to interface with LIDAR
- Schematics and models for the vest & soft 3d-printed nodes

# Known Bugs/WIP
The newest physical model of inflatables and circuitry is still waiting to be printed.

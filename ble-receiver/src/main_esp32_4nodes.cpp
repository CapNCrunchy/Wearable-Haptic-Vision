#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>

#define SERVICE_UUID "8b322909-2d3b-447b-a4d5-dfe0c009ec5a"
#define CHARACTERISTIC_RX "8b32290a-2d3b-447b-a4d5-dfe0c009ec5a"
#define CHARACTERISTIC_INFO "8b32290c-2d3b-447b-a4d5-dfe0c009ec5a"


#define SENSOR_SDA 25
#define SENSOR_SCL 26
#define XGZP_ADDRESS 0x6D
#define MUX_S0 32
#define MUX_S1 5
#define MUX_S2 33

const int NODE1_1 = 13; const int NODE1_2 = 14;
const int NODE2_1 = 18; const int NODE2_2 = 19;
const int NODE3_1 = 21; const int NODE3_2 = 22;
const int NODE4_1 = 23; const int NODE4_2 = 4;

BLEServer* pServer = NULL;
bool deviceConnected = false;
int currentStates[8] = {4, 4, 4, 4, 4, 4, 4, 4};
unsigned long lastSensorRead = 0;


void applyNodeState(int state, int pin1, int pin2) {
    if (state == 1) { 
        digitalWrite(pin1, LOW); digitalWrite(pin2, LOW);
    } else if (state == 2) {
        digitalWrite(pin1, LOW); digitalWrite(pin2, HIGH);
    } else if (state == 3) {
        digitalWrite(pin1, HIGH); digitalWrite(pin2, LOW);
    } else if (state == 4) { 
        digitalWrite(pin1, HIGH); digitalWrite(pin2, HIGH);
    } else {
        digitalWrite(pin1, LOW); digitalWrite(pin2, LOW); 
    }
}

int calculateState(float proximity) {
    if (isnan(proximity)) proximity = 0.0;
    if (proximity < 0.0) proximity = 0.0;
    if (proximity > 1.0) proximity = 1.0;
    if (proximity < 0.25) return 4;
    else if (proximity < 0.5) return 3;
    else if (proximity < 0.75) return 2;
    else return 1;
}

// Function to physically switch the 3x8 MUX
void setMuxChannel(int channel) {
    digitalWrite(MUX_S0, bitRead(channel, 0));
    digitalWrite(MUX_S1, bitRead(channel, 1));
    digitalWrite(MUX_S2, bitRead(channel, 2));
    delay(5); 
}

// Function to read a specific pressure sensor through the MUX
void readPressure(int channel) {
    setMuxChannel(channel);

    Wire1.beginTransmission(XGZP_ADDRESS);
    Wire1.write(0x30); 
    Wire1.write(0x0A); 
    if (Wire1.endTransmission() != 0) {
        Serial.printf("MUX Channel %d: No sensor responding.\n", channel);
        return;
    }

    delay(30);

    Wire1.beginTransmission(XGZP_ADDRESS);
    Wire1.write(0x06);
    Wire1.endTransmission(false);
    
    Wire1.requestFrom((uint16_t)XGZP_ADDRESS, (uint8_t)3);
    
    if (Wire1.available() == 3) {
        uint32_t dataHigh = Wire1.read();
        uint32_t dataMid  = Wire1.read();
        uint32_t dataLow  = Wire1.read();

        int32_t rawPressure = (dataHigh << 16) | (dataMid << 8) | dataLow;
        if (rawPressure & 0x800000) rawPressure -= 0x1000000;

        Serial.printf("Sensor on MUX Channel %d | Raw Pressure: %d\n", channel, rawPressure);
    }
}


class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        uint8_t* pData = pCharacteristic->getData();
        size_t length = pCharacteristic->getLength();
        
        // We check for 32 bytes so the iOS app doesn't need to be rewritten
        if (length >= 32) {
            float* incomingDistances = (float*)pData;
            int newStates[8] = {4, 4, 4, 4, 4, 4, 4, 4};
            
            for (int i = 0; i < 8; i++) {
                newStates[i] = calculateState(incomingDistances[i]);
            }

            bool stateChanged = false;
            for (int i = 0; i < 8; i++) {
                if (newStates[i] != currentStates[i]) {
                    stateChanged = true;
                    currentStates[i] = newStates[i];
                }
            }

            if (stateChanged) {
                // WE ONLY ACTUATE THE FIRST 4 NODES HERE
                applyNodeState(currentStates[0], NODE1_1, NODE1_2);
                applyNodeState(currentStates[1], NODE2_1, NODE2_2);
                applyNodeState(currentStates[2], NODE3_1, NODE3_2);
                applyNodeState(currentStates[3], NODE4_1, NODE4_2);
                
                Serial.printf("Vest Updated: N1:%d N2:%d N3:%d N4:%d (Nodes 5-8 Ignored)\n", 
                              currentStates[0], currentStates[1], currentStates[2], currentStates[3]);
            }
        }
    }
};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("iPhone Connected!");
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("iPhone Disconnected. Deflating Nodes 1-4.");
      
      // Deflate only the 4 nodes safely
      int allPins[] = {NODE1_1, NODE1_2, NODE2_1, NODE2_2, NODE3_1, NODE3_2, NODE4_1, NODE4_2};
      for (int i = 0; i < 8; i++) {
          digitalWrite(allPins[i], HIGH); 
      }
      pServer->startAdvertising(); 
    }
};

void setup() {
    Serial.begin(115200);

    
    pinMode(MUX_S0, OUTPUT);
    pinMode(MUX_S1, OUTPUT);
    pinMode(MUX_S2, OUTPUT);

    
    int allPins[] = {NODE1_1, NODE1_2, NODE2_1, NODE2_2, NODE3_1, NODE3_2, NODE4_1, NODE4_2};
    for (int i = 0; i < 8; i++) {
        pinMode(allPins[i], OUTPUT);
        digitalWrite(allPins[i], HIGH); 
    }
    Serial.println("Direct Valve Pins for Nodes 1-4 Initialized!");

    
    Wire1.begin(SENSOR_SDA, SENSOR_SCL);
    Serial.println("I2C Sensor Bus Initialized on Pins 25 & 26.");

    
    BLEDevice::init("WHV Haptic Receiver"); 
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    BLEService *pService = pServer->createService(SERVICE_UUID);
    BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                                             CHARACTERISTIC_RX,
                                             BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
                                           );
    pRxCharacteristic->setCallbacks(new MyCallbacks());
    BLECharacteristic *pInfoCharacteristic = pService->createCharacteristic(
                                             CHARACTERISTIC_INFO,
                                             BLECharacteristic::PROPERTY_READ
                                           );
    pInfoCharacteristic->setValue("WHV ESP32 v5.1 (4-Node Test)");
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    
    Serial.println("ESP32 System Ready!");
}

void loop() {
    // Read the pressure sensors every 500 milliseconds
    if (millis() - lastSensorRead > 500) {
        
        
        readPressure(0);
        
        
        readPressure(1);
        
        Serial.println("---");
        lastSensorRead = millis();
    }
    
    // Tiny delay to keep the background BLE tasks happy
    delay(10); 
}
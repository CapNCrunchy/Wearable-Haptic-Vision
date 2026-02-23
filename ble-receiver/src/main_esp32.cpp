#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID "8b322909-2d3b-447b-a4d5-dfe0c009ec5a"
#define CHARACTERISTIC_RX "8b32290a-2d3b-447b-a4d5-dfe0c009ec5a"
#define CHARACTERISTIC_INFO "8b32290c-2d3b-447b-a4d5-dfe0c009ec5a"

// ESP32 Pin Mappings
const int ALL_NODES_ON = 2; 

const int NODE1_1 = 13; const int NODE1_2 = 12;
const int NODE2_1 = 14; const int NODE2_2 = 27;
const int NODE3_1 = 26; const int NODE3_2 = 25;
const int NODE4_1 = 33; const int NODE4_2 = 32;
const int NODE5_1 = 15; const int NODE5_2 = 4;

// Moved away from PSRAM crash pins (16 & 17) to safe pins (5 & 23)
const int NODE6_1 = 5;  const int NODE6_2 = 23;

const int NODE7_1 = 18; const int NODE7_2 = 19;
const int NODE8_1 = 21; const int NODE8_2 = 22;

BLEServer* pServer = NULL;
bool deviceConnected = false;

// Helper
void applyNodeState(int state, int pin1, int pin2) {
    if (state == 1) { // Max Inflation
        digitalWrite(pin1, LOW);
        digitalWrite(pin2, LOW);
    } else if (state == 2) {
        digitalWrite(pin1, LOW);
        digitalWrite(pin2, HIGH);
    } else if (state == 3) {
        digitalWrite(pin1, HIGH);
        digitalWrite(pin2, LOW);
    } else if (state == 4) { // Deflated / Safe
        digitalWrite(pin1, HIGH);
        digitalWrite(pin2, HIGH);
    } else {
        digitalWrite(pin1, LOW);
        digitalWrite(pin2, LOW); 
    }
}

// Math Translation: Floats (0.0-1.0) to States (1-4)
int calculateState(float proximity) {
    if (isnan(proximity)) proximity = 0.0;
    if (proximity < 0.0) proximity = 0.0;
    if (proximity > 1.0) proximity = 1.0;

    if (proximity < 0.25) return 4;
    else if (proximity < 0.5) return 3;
    else if (proximity < 0.75) return 2;
    else return 1;
}

// Global array to remember the current state of the vest
int currentStates[8] = {4, 4, 4, 4, 4, 4, 4, 4};

// BLE Callback for when the iOS app sends raw float bytes
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        uint8_t* pData = pCharacteristic->getData();
        size_t length = pCharacteristic->getLength();

        
        // 8 floats * 4 bytes per float = 32 bytes
        if (length >= 32) {
            // Treat the raw byte array directly as an array of floats
            float* incomingDistances = (float*)pData;
            
            int newStates[8] = {4, 4, 4, 4, 4, 4, 4, 4};
            
            for (int i = 0; i < 8; i++) {
                newStates[i] = calculateState(incomingDistances[i]);
            }

            // Check if anything actually changed
            bool stateChanged = false;
            for (int i = 0; i < 8; i++) {
                if (newStates[i] != currentStates[i]) {
                    stateChanged = true;
                    currentStates[i] = newStates[i]; // Update our memory
                }
            }

            // Update only if changed
            if (stateChanged) {
                applyNodeState(currentStates[0], NODE1_1, NODE1_2);
                applyNodeState(currentStates[1], NODE2_1, NODE2_2);
                applyNodeState(currentStates[2], NODE3_1, NODE3_2);
                applyNodeState(currentStates[3], NODE4_1, NODE4_2);
                applyNodeState(currentStates[4], NODE5_1, NODE5_2);
                applyNodeState(currentStates[5], NODE6_1, NODE6_2);
                applyNodeState(currentStates[6], NODE7_1, NODE7_2);
                applyNodeState(currentStates[7], NODE8_1, NODE8_2);
                
                Serial.printf("Vest Updated: %d %d %d %d %d %d %d %d\n", 
                              currentStates[0], currentStates[1], currentStates[2], currentStates[3], 
                              currentStates[4], currentStates[5], currentStates[6], currentStates[7]);
            }
        } else if (length > 0) {
            Serial.printf("Error: Expected 32 bytes (8 floats), but received %d bytes\n", length);
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
      Serial.println("iPhone Disconnected. Resetting all nodes to State 4.");
      
      int deflated = 4; 
      applyNodeState(deflated, NODE1_1, NODE1_2);
      applyNodeState(deflated, NODE2_1, NODE2_2);
      applyNodeState(deflated, NODE3_1, NODE3_2);
      applyNodeState(deflated, NODE4_1, NODE4_2);
      applyNodeState(deflated, NODE5_1, NODE5_2);
      applyNodeState(deflated, NODE6_1, NODE6_2);
      applyNodeState(deflated, NODE7_1, NODE7_2);
      applyNodeState(deflated, NODE8_1, NODE8_2);
      
      pServer->startAdvertising(); 
    }
};

void setup() {
    Serial.begin(115200);

    int allPins[] = {ALL_NODES_ON, NODE1_1, NODE1_2, NODE2_1, NODE2_2, 
                     NODE3_1, NODE3_2, NODE4_1, NODE4_2, NODE5_1, 
                     NODE5_2, NODE6_1, NODE6_2, NODE7_1, NODE7_2, NODE8_1, NODE8_2};
                     
    for (int i = 0; i < 17; i++) {
        pinMode(allPins[i], OUTPUT);
        digitalWrite(allPins[i], HIGH); 
    }
    
    digitalWrite(ALL_NODES_ON, HIGH);

    BLEDevice::init("WHV Haptic Receiver"); 
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);

    BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                                             CHARACTERISTIC_RX,
                                             BLECharacteristic::PROPERTY_WRITE |
                                             BLECharacteristic::PROPERTY_WRITE_NR
                                           );
    pRxCharacteristic->setCallbacks(new MyCallbacks());

    BLECharacteristic *pInfoCharacteristic = pService->createCharacteristic(
                                             CHARACTERISTIC_INFO,
                                             BLECharacteristic::PROPERTY_READ
                                           );
    pInfoCharacteristic->setValue("WHV ESP32 Raw Float Receiver");

    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    
    Serial.println("ESP32 BLE Server is up!");
}

void loop() {
    delay(1); 
}
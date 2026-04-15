const int nodePins[8] = {
    12, // Node 1
    14, // Node 2
    22, // Node 3
    26, // Node 4
    25, // Node 5
    33, // Node 6
    32, // Node 7
    23  // Node 8
};

const int INFLATE_TIME = 1000;
const int DEFLATE_TIME = 1000;

void setup() {
    Serial.begin(115200);
    Serial.println("8 Node Test (1 Pin Per Node)");

    for (int i = 0; i < 8; i++) {
        pinMode(nodePins[i], OUTPUT);
        digitalWrite(nodePins[i], LOW);
    }
    
    Serial.println("All 8 valves initialized to LOW (Closed).");
    Serial.println("Starting sequence...");
    delay(1000);
}

void loop() {
    for (int i = 0; i < 8; i++) {
        int nodeNumber = i + 1;
        int pin = nodePins[i];

        Serial.printf("Node %d (Pin %d): HIGH -> Blowing Air In\n", nodeNumber, pin);
        digitalWrite(pin, HIGH);
        
        delay(INFLATE_TIME); 

        Serial.printf("Node %d (Pin %d): LOW  -> Removing Air\n", nodeNumber, pin);
        digitalWrite(pin, LOW);
        
        delay(DEFLATE_TIME); 
        
        Serial.println("---------------------------------");
    }

    Serial.println("Sequence Complete. Restarting");
    delay(500);
}

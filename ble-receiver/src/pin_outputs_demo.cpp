void setup() {
    Serial.begin(115200);

    int pins[] = {13, 14, 27, 26, 25, 4, 18, 19};

    for (int i = 0; i < 8; i++) {
        pinMode(pins[i], OUTPUT);
        digitalWrite(pins[i], HIGH);
    }

    Serial.println("All 8 pins driven HIGH.");
}

void loop() {}

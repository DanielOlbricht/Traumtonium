void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
}

void loop() {
  static long sumA0 = 0, sumA4 = 0, sumA1 = 0;
  static long sumA2 = 0, sumA5 = 0, sumA3 = 0;
  static int count = 0;

  sumA0 += analogRead(A0);
  sumA4 += analogRead(A1);
  sumA1 += analogRead(A2);
  sumA2 += analogRead(A3);
  sumA5 += analogRead(A4);
  sumA3 += analogRead(A5);
  count++;

  if (count >= 10) {
    Serial.print("pitch1: ");  Serial.println(sumA0 / count);
    Serial.print("press1L: "); Serial.println(sumA4 / count);
    Serial.print("press1R: "); Serial.println(sumA1 / count);
    Serial.print("pitch2: ");  Serial.println(sumA2 / count);
    Serial.print("press2L: "); Serial.println(sumA5 / count);
    Serial.print("press2R: "); Serial.println(sumA3 / count);
    Serial.println("---");
    sumA0 = sumA4 = sumA1 = sumA2 = sumA5 = sumA3 = 0;
    count = 0;
  }

  delay(50);
}
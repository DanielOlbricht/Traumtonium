float pitch1_s = 0, press1L_s = 0, press1R_s = 0;
float pitch2_s = 0, press2L_s = 0, press2R_s = 0;
// globale Variablen, da die werte über den loop hinaus überleben sollen.
// sonst wäre pitch1_s immer nur 0.45*pitch1_raw






void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
}

void loop() {
  int pitch1_raw  = map(analogRead(A0), 10,   4086, 0, 2400);
  int press1L_raw = map(analogRead(A1), 62,   1276, 500, 0);
  int press1R_raw = map(analogRead(A2), 52,   1300, 500, 0);
  int pitch2_raw  = map(analogRead(A3), 10,   4086, 0, 2400);
  int press2L_raw = map(analogRead(A4), 60,   1288, 500, 0);
  int press2R_raw = map(analogRead(A5), 57,   1290, 500, 0);

  pitch1_s  = 0.5 * pitch1_s  + 0.5 * pitch1_raw;    //mehr Vergangenheit oder mehr Neuheit (raw)
  press1L_s = 0.5 * press1L_s + 0.5 * press1L_raw;
  press1R_s = 0.5 * press1R_s + 0.5 * press1R_raw;
  pitch2_s  = 0.5 * pitch2_s  + 0.5 * pitch2_raw;
  press2L_s = 0.5 * press2L_s + 0.5 * press2L_raw;
  press2R_s = 0.5 * press2R_s + 0.5 * press2R_raw;

  int press1 = (int)max(press1L_s, press1R_s);
  int press2 = (int)max(press2L_s, press2R_s);

  static int lastPitch1 = 0; //static variablen werden nur beim ersten duchrlauf gesetzt. ab dem zweiten werden die zeilen ignoriert. 
  static int lastPitch2 = 0;

  bool silent = (press1 <= 8 && press2 <= 8);
   // schwellenwert sind Empfindlichkeitsstellschrauben, die auch unterschiedlich sein können
   // wenn nicht gedrückt -> True
   // wenn gedrückt -> False
  static bool wasSilent = false;

  if (silent == false) {
    lastPitch1 = (int)pitch1_s;
    lastPitch2 = (int)pitch2_s;
    Serial.print(lastPitch1);
    Serial.print(",");
    Serial.print(press1);
    Serial.print(",");
    Serial.print(lastPitch2);
    Serial.print(",");
    Serial.println(press2);
    wasSilent = false;
    //else if wird geprüft, wenn if nicht erfüllt ist
  } else if (wasSilent == false) {
    Serial.print(lastPitch1);
    Serial.print(",0,");
    Serial.print(lastPitch2);
    Serial.println(",0");
    wasSilent = true;
  }

  delay(5);
}










// =====================================================================
//  Pierna Klann - control del motor y registro de datos
//  Arduino Nano + L298N + INA219 + JGA25-370 con encoder
//
//  - Potenciometro en A0: velocidad (PWM en ENA = D9)
//  - Encoder A/B en D2/D3 (interrupciones): angulo y velocidad
//  - INA219 por I2C (A4/A5): corriente y voltaje del motor
//  - Envia por Serial (115200) una linea CSV cada 10 ms:
//        t_ms, cuentas, angulo_manivela_deg, rpm_manivela, corriente_mA, voltaje_V
//    Copiar el Monitor Serie a un .csv, o leerlo con Klann_Torque.m
//
//  Libreria necesaria: "Adafruit INA219" (Gestor de librerias del IDE).
// =====================================================================
#include <Wire.h>
#include <Adafruit_INA219.h>

// ---------- pines ----------
const int PIN_ENA = 9;    // PWM
const int PIN_IN1 = 7;
const int PIN_IN2 = 8;
const int PIN_ENC_A = 2;  // INT0
const int PIN_ENC_B = 3;  // INT1
const int PIN_POT = A0;

// ---------- parametros (AJUSTAR) ----------
// Cuentas del encoder por vuelta del EJE DE SALIDA del motor, en cuadratura (x4).
// JGA25 tipico: 11 pulsos/vuelta del rotor x reduccion x 4. Si no se conoce la
// reduccion: girar a mano 10 vueltas del eje de salida y dividir las cuentas entre 10.
const long CUENTAS_POR_VUELTA_MOTOR = 11L * 34L * 4L;   // <-- CAMBIAR
const float RELACION_ENGRANAJES = 2.0;                   // 36/18: manivela = motor/2
const unsigned long PERIODO_MS = 10;

Adafruit_INA219 ina;
volatile long cuentas = 0;

void isrA() { cuentas += (digitalRead(PIN_ENC_A) == digitalRead(PIN_ENC_B)) ? 1 : -1; }
void isrB() { cuentas += (digitalRead(PIN_ENC_A) != digitalRead(PIN_ENC_B)) ? 1 : -1; }

void setup() {
  Serial.begin(115200);
  pinMode(PIN_ENA, OUTPUT); pinMode(PIN_IN1, OUTPUT); pinMode(PIN_IN2, OUTPUT);
  pinMode(PIN_ENC_A, INPUT_PULLUP); pinMode(PIN_ENC_B, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_A), isrA, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_B), isrB, CHANGE);
  digitalWrite(PIN_IN1, HIGH); digitalWrite(PIN_IN2, LOW);   // sentido antihorario de la manivela
  if (!ina.begin()) { Serial.println("ERROR: no se encuentra el INA219"); while (1) {} }
  ina.setCalibration_32V_2A();
  Serial.println("t_ms,cuentas,angulo_deg,rpm_manivela,corriente_mA,voltaje_V");
}

void loop() {
  static unsigned long t0 = millis(), tPrev = 0;
  static long cPrev = 0;
  unsigned long t = millis() - t0;
  if (t - tPrev < PERIODO_MS) return;

  int pwm = map(analogRead(PIN_POT), 0, 1023, 0, 255);
  analogWrite(PIN_ENA, pwm);

  noInterrupts(); long c = cuentas; interrupts();
  const float cuentasManivela = CUENTAS_POR_VUELTA_MOTOR * RELACION_ENGRANAJES;
  float ang = fmod(360.0 * c / cuentasManivela, 360.0); if (ang < 0) ang += 360.0;
  float rpm = (c - cPrev) / cuentasManivela / ((t - tPrev) / 60000.0);
  float mA = ina.getCurrent_mA();
  float V  = ina.getBusVoltage_V() + ina.getShuntVoltage_mV() / 1000.0;

  Serial.print(t); Serial.print(','); Serial.print(c); Serial.print(',');
  Serial.print(ang, 2); Serial.print(','); Serial.print(rpm, 2); Serial.print(',');
  Serial.print(mA, 1); Serial.print(','); Serial.println(V, 3);
  tPrev = t; cPrev = c;
}

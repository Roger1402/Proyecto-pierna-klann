// =====================================================================
//  Pierna Klann - ESP32-S3 + L298N + JGA25-370 con encoder
//
//  Conexiones (ver diagrama_circuito_esp32.png):
//    GPIO4  -> ENA (PWM, quitar el jumper de ENA del L298N)
//    GPIO5  -> IN1        GPIO6 -> IN2
//    GPIO15 <- encoder A  GPIO16 <- encoder B   (encoder alimentado a 3V3, NO 5 V)
//    GND del ESP32 unido a GND del driver, de la fuente y del encoder.
//
//  Uso desde el Monitor Serie (115200 baudios, "Nueva linea"):
//    0..100  -> PWM en %   (ej.: escribir 60 y Enter)
//    r       -> invertir el sentido de giro
//    z       -> poner el angulo en cero (marcar la pose de referencia)
//  Salida: una linea CSV cada 10 ms
//    t_ms, cuentas, angulo_deg, rpm_manivela, rpm_motor, pwm_pct, A, B, nA, nB, err
//    nA/nB = cambios vistos en cada canal (deben subir casi iguales)
//    err   = saltos imposibles (ruido o pulsos perdidos; debe quedarse casi fijo)
//  Copiar el texto del Monitor Serie a un archivo .csv para Klann_Torque.m
//
//  Placa en el IDE: "ESP32S3 Dev Module". Si se usa el puerto USB nativo,
//  activar Herramientas > "USB CDC On Boot: Enabled".
//  Si se usa el puerto COM/UART (CH343): "USB CDC On Boot: Disabled".
// =====================================================================

const int PIN_ENA = 4, PIN_IN1 = 5, PIN_IN2 = 6;
const int PIN_ENC_A = 15, PIN_ENC_B = 16;
const int PWM_FREQ = 1000;    // 1 kHz: el L298N es lento, a 20 kHz pierde fuerza
const int PWM_BITS = 8;       // 0..255

// Cuentas del encoder por vuelta del EJE DE SALIDA del motor (cuadratura x4).
// JGA25 tipico: 11 pulsos por vuelta del rotor x reduccion x 4.
// Si no se conoce la reduccion: escribir z, girar a mano 10 vueltas el eje de
// salida y dividir las "cuentas" mostradas entre 10.   <-- AJUSTAR
const long CUENTAS_POR_VUELTA_MOTOR = 11L * 34L * 4L;
const float RELACION_ENGRANAJES = 2.0;   // 36/18: la manivela gira a la mitad
const unsigned long PERIODO_MS = 10;

volatile long cuentas = 0, nA = 0, nB = 0, errores = 0;
volatile uint8_t estado = 0;
unsigned long tLatido = 0;      // 0 = sin interfaz web (Monitor Serie)
int pwmPct = 0;
bool sentido = true;

// Cuadratura x4 por tabla: solo cuenta transiciones validas; 2 = salto imposible
DRAM_ATTR const int8_t TABLA[16] = { 0, 1, -1, 2,   -1, 0, 2, 1,   1, 2, 0, -1,   2, -1, 1, 0 };
void IRAM_ATTR isrEncoder() {
  uint8_t nuevo = (digitalRead(PIN_ENC_A) << 1) | digitalRead(PIN_ENC_B);
  uint8_t cambio = nuevo ^ estado;
  if (cambio & 2) nA = nA + 1;
  if (cambio & 1) nB = nB + 1;
  int8_t d = TABLA[(estado << 2) | nuevo];
  if (d == 2) errores = errores + 1; else cuentas = cuentas + d;
  estado = nuevo;
}

void aplicarMotor() {
  digitalWrite(PIN_IN1, sentido ? HIGH : LOW);
  digitalWrite(PIN_IN2, sentido ? LOW : HIGH);
  int duty = map(pwmPct, 0, 100, 0, (1 << PWM_BITS) - 1);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(PIN_ENA, duty);
#else
  ledcWrite(0, duty);
#endif
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_IN1, OUTPUT); pinMode(PIN_IN2, OUTPUT);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(PIN_ENA, PWM_FREQ, PWM_BITS);
#else
  ledcSetup(0, PWM_FREQ, PWM_BITS); ledcAttachPin(PIN_ENA, 0);
#endif
  pinMode(PIN_ENC_A, INPUT_PULLUP); pinMode(PIN_ENC_B, INPUT_PULLUP);
  estado = (digitalRead(PIN_ENC_A) << 1) | digitalRead(PIN_ENC_B);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_A), isrEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_B), isrEncoder, CHANGE);
  aplicarMotor();
  delay(500);
  Serial.println("KLANN_OK");
  Serial.println("t_ms,cuentas,angulo_deg,rpm_manivela,rpm_motor,pwm_pct,A,B,nA,nB,err");
}

void leerComandos() {
  if (!Serial.available()) return;
  String s = Serial.readStringUntil('\n'); s.trim();
  if (s == "r") { sentido = !sentido; }
  else if (s == "z") { noInterrupts(); cuentas = 0; nA = nB = errores = 0; interrupts(); }
  else if (s == "k") { tLatido = millis(); return; }          // latido de la interfaz
  else if (s.length() > 0 && isDigit(s[0])) { pwmPct = constrain(s.toInt(), 0, 100); }
  aplicarMotor();
}

void loop() {
  static unsigned long tPrev = 0; static long cPrev = 0;
  leerComandos();
  // seguridad: si la interfaz web se cierra, parar el motor
  if (tLatido && millis() - tLatido > 2000) { tLatido = 0; pwmPct = 0; aplicarMotor(); }
  unsigned long t = millis();
  if (t - tPrev < PERIODO_MS) return;

  noInterrupts(); long c = cuentas, a = nA, b = nB, e = errores; interrupts();
  const float cMotor = CUENTAS_POR_VUELTA_MOTOR;
  const float cManivela = cMotor * RELACION_ENGRANAJES;
  float dtMin = (t - tPrev) / 60000.0;
  float rpmMotor = (c - cPrev) / cMotor / dtMin;
  float rpmManivela = rpmMotor / RELACION_ENGRANAJES;
  float ang = fmod(360.0 * c / cManivela, 360.0); if (ang < 0) ang += 360.0;

  Serial.printf("%lu,%ld,%.2f,%.2f,%.2f,%d,%d,%d,%ld,%ld,%ld\n", t, c, ang, rpmManivela, rpmMotor, pwmPct,
                digitalRead(PIN_ENC_A), digitalRead(PIN_ENC_B), a, b, e);
  tPrev = t; cPrev = c;
}

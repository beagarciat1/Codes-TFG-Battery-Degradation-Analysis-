#include <PIDController.hpp>
// PID::PIDParameters<double> parametersI_aggresive(0.2, 0.8, 0.01); para 0.5 s
//PID::PIDParameters<double> parametersI_aggresive(0.5, 2, 0.01);
PID::PIDParameters<double> parametersI_aggresive(4, 3.5, 0.01);
PID::PIDParameters<double> parametersI_conservative(4, 3.5, 0.01);
// PID::PIDParametersAdaptative<double> adaptative(10, conservative, 100, aggresive);
PID::PIDController<double> pidControllerI(parametersI_aggresive);

PID::PIDParameters<double> parametersV_aggresive(1, 10, 0);
PID::PIDController<double> pidControllerV(parametersV_aggresive);
const double Vmin = 3000;//2500;
const double Vmax = 4200;//4300;
const double thres = 10;
const double C = 150;
const double C_30 = C / 30;//33.33;

bool mode = 1;
int state = 0;
int N = 5;
int cycle = 0;
const int PIN_OUTPUT = A0;
float valorVDC = 0;
float valorADC = 0;
unsigned int timer = millis();
unsigned int flag = millis();

// Variables para SOC y pausas
float cargaAcumulada = 0;
const float CAPACIDAD_NOMINAL = 150.0; // mAh - AJUSTAR SEGÚN TU BATERÍA
int socLevel = 0;
unsigned long lastChargeTime = 0;
bool pausaActiva = false;
unsigned int timerPausa = 0;
int estadoAntesDePausa = 1; // Guarda el estado previo a la pausa

void CC(double Crate) {
    pidControllerV.TurnOff();
    mode = 1;
    if (Crate > 0.1) pidControllerI.SetOutputLimits(4095 / 2 - 100, 4095); //CARGA
    else if (Crate < -0.1) pidControllerI.SetOutputLimits(0, 4095 / 2 + 100); //DESCARGA
    else pidControllerI.SetOutputLimits(4095 / 2 - 100, 4095 / 2 + 100); //REPOSO
    pidControllerI.Setpoint = Crate; //VALOR OBJETIVO DE CORRIENTE
    pidControllerI.TurnOn(); //ACTIVA CONTROL DE CORRIENTE
}

void CV(double Vref) {
    pidControllerI.TurnOff();
    mode = 0;
    if (Vref == Vmax) pidControllerV.SetOutputLimits(4095 / 2 - 100, 4095 - 300);
    else if (Vref == Vmin)pidControllerV.SetOutputLimits(300, 4095 + 100);
    pidControllerV.Setpoint = Vref;
    pidControllerV.TurnOn();
}

// Función para actualizar carga acumulada
void actualizarCarga() {
    unsigned long tiempoActual = millis();
    float dt = (tiempoActual - lastChargeTime) / 3600000.0; // Convierte ms a horas

    // Acumula carga solo si está en state 1 (cargando) y no está en pausa
    if (!pausaActiva && valorADC > 0) {
        cargaAcumulada += valorADC * dt; // mAh
    }

    lastChargeTime = tiempoActual;
}

// Función: Chequea comandos de control
void checkComandos() {
    if (!pausaActiva) return;

    if (Serial.available() > 0) {
        char cmd = Serial.read();

        if (cmd == 'C' || cmd == 'c') {
            Serial.println("");
            Serial.println(">>> Comando 'C' recibido: Reanudando carga...");
            pausaActiva = false;
            lastChargeTime = millis();
            state = estadoAntesDePausa;

            if (estadoAntesDePausa == 1) {
                CC(C);  // State 1 → CC carga
            }
            else if (estadoAntesDePausa == 2) {
                CC(0);  // State 2 → Reposo
            }
        }
    }
}

void get_data() {
    if (Serial.available() > 0) {
        // Leer la cadena del puerto serie
        String data = Serial.readStringUntil('\n');
        Serial.print(", Ciclo, ");
        Serial.print(cycle);
        // Convertir la cadena en números decimales
        float valorADC2 = atof(data.substring(0, data.indexOf(" ADC")).c_str());
        float valorVDC2 = atof(data.substring(data.lastIndexOf(",") + 1, data.indexOf(" VDC")).c_str());

        // Imprimir los valores
        valorADC = -valorADC2 * 1000;
        valorVDC = valorVDC2 * 1000;
        Serial.print(", State, ");
        Serial.print(state);
        Serial.print(", Valor_VDC, ");
        Serial.print(valorVDC, 6);
        Serial.print(", Valor_ADC, ");
        Serial.print(valorADC, 6);

        // Imprimir SOC
        float soc = (cargaAcumulada / CAPACIDAD_NOMINAL) * 100;
        Serial.print(", SOC_%, ");
        Serial.print(soc, 2);
        Serial.print(", Carga_mAh, ");
        Serial.print(cargaAcumulada, 2);

        if (mode) {
            if (valorADC > pidControllerI.Setpoint - thres && valorADC < pidControllerI.Setpoint + thres) {
                pidControllerI.SetTunings(parametersI_conservative);
                pidControllerI.Input = valorADC;
                pidControllerI.Update();
            }
            double dacValueI = pidControllerI.Output;
            Serial.print(", DAC, ");
            Serial.println(dacValueI, 6);
            analogWrite(PIN_OUTPUT, (int)dacValueI);
        }
        else {
            pidControllerV.SetTunings(parametersV_aggresive);
            pidControllerV.Input = valorVDC;
            pidControllerV.Update();
            double dacValueV = pidControllerV.Output;
            Serial.print(", DAC, ");
            Serial.println(dacValueV, 6);
            analogWrite(PIN_OUTPUT, (int)dacValueV);
        }
    }

    if (mode) {
        if (valorADC<pidControllerI.Setpoint - thres || valorADC>pidControllerI.Setpoint + thres) {
            pidControllerI.SetTunings(parametersI_aggresive);
            pidControllerI.Input = valorADC;
            pidControllerI.Update();
        }
    }
}

void setup() {
    Serial.begin(9600);
    delay(5000);
    analogWrite(PIN_OUTPUT, 4095 / 2);
    analogWriteResolution(12);
    pidControllerI.SetOutputLimits(0, 4095);
    pidControllerV.SetOutputLimits(1700, 3300);
    pidControllerI.SetOutputLimits(4095 / 2 - 20, 4095 / 2 + 20);
    pidControllerI.Setpoint = 0;
    pidControllerV.Setpoint = Vmin;
    pidControllerV.TurnOff();
    pidControllerI.TurnOn();
    analogWrite(PIN_OUTPUT, 4095 / 2);
    mode = 1;

    cycle = 0;
    timer = millis();
    flag = millis();
    state = 0;

    // Inicializa variables de SOC
    cargaAcumulada = 0;
    socLevel = 0;
    lastChargeTime = millis();
    pausaActiva = false;
    estadoAntesDePausa = 1;

    Serial.println("========================================");
    Serial.println("Sistema CC con Pausas por SOC");
    Serial.println("========================================");
    Serial.println("Pausas programadas en: 2% 5% 20%, 40%, 60%, 80%");
    Serial.println("Envia 'C' para continuar despues de cada pausa");
    Serial.println("========================================");
}

void loop() {
    checkComandos();

    if (millis() - flag > 50) {
        get_data();
        actualizarCarga();
        flag = millis();
    }

    // CHEQUEOS DE SOC (FUERA DE LOS ESTADOS)
    float soc = cargaAcumulada / CAPACIDAD_NOMINAL;

    // Pausa en 2% SOC
    if (socLevel == 0 && soc >= 0.02 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        socLevel = 1;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 2% - Carga: ");
        Serial.print(cargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }


    if (socLevel == 1 && soc >= 0.05 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        socLevel = 2;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 5% - Carga: ");
        Serial.print(cargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    if (socLevel == 2 && soc >= 0.2 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        socLevel = 3;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 20% - Carga: ");
        Serial.print(cargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    if (socLevel == 3 && soc >= 0.4 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        socLevel = 4;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 40% - Carga: ");
        Serial.print(cargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    if (socLevel == 4 && soc >= 0.6 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        socLevel = 5;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 60% - Carga: ");
        Serial.print(cargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    if (socLevel == 5 && soc >= 0.8 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        socLevel = 6;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 80% - Carga: ");
        Serial.print(cargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    // GESTIÓN DE ESTADOS
    if (state == 0) {
        if (!cycle) {
            if (millis() - timer > 10000) {
                CC(C);
                cargaAcumulada = 0;
                socLevel = 0;
                lastChargeTime = millis();
                pausaActiva = false;
                state = 1;
            }
        }
    }

    if (state == 1) {
        if (valorVDC >= Vmax) {
            CC(0);
            state = 0;
            timer = millis();
            cycle++;
        }

        Serial.println("");
        Serial.println("========================================");
        Serial.println(">>> CARGA COMPLETADA AL 100%");
    }

    if (state == 2) {
        if (valorVDC <= Vmin) {
            CC(0);
            state = 3;
            timer = millis();
        }
    }

    if (state == 3) {
        if (valorVDC <= 3600) {
            CC(0);
            state = 0;
            cycle++;
        }
    }

    if (state == 6) {
        if (millis() - timerPausa > 30000) {
            Serial.println(">>> En pausa - Esperando comando 'C'...");
            timerPausa = millis();
        }
    }
}
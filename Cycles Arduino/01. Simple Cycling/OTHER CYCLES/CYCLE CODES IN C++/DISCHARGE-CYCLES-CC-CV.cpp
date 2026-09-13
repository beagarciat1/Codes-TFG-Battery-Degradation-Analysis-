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
//const double wait_time=7200000; //7200000
unsigned int timer = millis();
//unsigned int timer2=millis();
unsigned int flag = millis();

float descargaAcumulada = 0;
const float CAPACIDAD_NOMINAL = 150.0; // mAh - AJUSTAR SEGÚN TU BATERÍA
int dodLevel = 0; // Depth of Discharge Level
unsigned long lastDischargeTime = 0;
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

void actualizarDescarga() {
    unsigned long tiempoActual = millis();
    float dt = (tiempoActual - lastDischargeTime) / 3600000.0; // Convierte ms a horas

    // Acumula descarga solo si está descargando (corriente negativa) y no está en pausa
    if (!pausaActiva && valorADC < 0) {
        descargaAcumulada += abs(valorADC) * dt; // mAh (valor absoluto)
    }

    lastDischargeTime = tiempoActual;
}

void checkComandos() {
    if (!pausaActiva) return;

    if (Serial.available() > 0) {
        char cmd = Serial.read();

        if (cmd == 'C' || cmd == 'c') {
            Serial.println("");
            Serial.println(">>> Comando 'C' recibido: Reanudando descarga...");
            pausaActiva = false;
            lastDischargeTime = millis();
            state = estadoAntesDePausa;

            if (estadoAntesDePausa == 1) {
                CC(-C);  // State 1 → CC descarga
            }
            else if (estadoAntesDePausa == 2) {
                CV(Vmin);  // State 2 → CV descarga
            }
			else if (estadoAntesDePausa == 3) {
				CC(0);  // State 3 → Reposo
        }
    }
}


void get_data() {
    if (Serial.available() > 0) {
        // Leer la cadena del puerto serie
        String data = Serial.readStringUntil('\n');
        // Serial.print("Arduino:  " + data);
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
        Serial.print(valorVDC, 6); // Imprimir con 5 decimales de precisión
        Serial.print(", Valor_ADC, ");
        Serial.print(valorADC, 6);

        float dod = (descargaAcumulada / CAPACIDAD_NOMINAL) * 100;
        float socRestante = 100.0 - dod; // SOC restante
        Serial.print(", DoD_%, ");
        Serial.print(dod, 2);
        Serial.print(", SOC_restante_%, ");
        Serial.print(socRestante, 2);
        Serial.print(", Descarga_mAh, ");
        Serial.print(descargaAcumulada, 2);


        // put your main code here, to run repeatedly:
        // int dacValue = (2.5+pidControllerI.Output/500 )/5 * (4096 - 1);
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
    if (mode) { //se ejecuta cada vez que se llama a get_data, llegue un dato o no
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
    //Serial.setTimeout(1);
    analogWriteResolution(12);
    pidControllerI.SetOutputLimits(0, 4095);
    pidControllerV.SetOutputLimits(1700, 3300);
    pidControllerI.SetOutputLimits(4095 / 2 - 20, 4095 / 2 + 20);
    pidControllerI.Setpoint = 0;
    pidControllerV.Setpoint = Vmin;     // The "goal" the PID controller tries to "reach"  // Tune the PID, arguments: kP, kI, kD
    //pidControllerI.TurnOn();
    pidControllerV.TurnOff();
    pidControllerI.TurnOn();
    analogWrite(PIN_OUTPUT, 4095 / 2);
    mode = 1;

    cycle = 0;
    timer = millis();
    flag = millis();
    state = 0;

    // Inicializa variables de DoD
    descargaAcumulada = 0;
    dodLevel = 0;
    lastDischargeTime = millis();
    pausaActiva = false;
    estadoAntesDePausa = 1;

    Serial.println("========================================");
    Serial.println("Sistema de Descarga con Pausas por DoD");
    Serial.println("========================================");
    Serial.println("Pausas programadas en SOC: 98%, 95%, 80%, 60%, 40%, 20%");
    Serial.println("(Equivalente a DoD: 2%, 5%, 20%, 40%, 60%, 80%)");
    Serial.println("Envia 'C' para continuar despues de cada pausa");
    Serial.println("========================================");
}

void loop() {

    checkComandos();
    if (millis() - flag > 50) {
        get_data();
        actualizarDescarga();
        flag = millis();
    }

    // CHEQUEOS DE DoD (FUERA DE LOS ESTADOS)
    float dod = descargaAcumulada / CAPACIDAD_NOMINAL;
    float socRestante = 1.0 - dod; // SOC restante (0.0 a 1.0)

    // Pausa cuando SOC = 98% (DoD = 2%)
    if (dodLevel == 0 && dod >= 0.02 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        dodLevel = 1;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 98% (DoD 2%) - Descarga: ");
        Serial.print(descargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    // Pausa cuando SOC = 95% (DoD = 5%)
    if (dodLevel == 1 && dod >= 0.05 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        dodLevel = 2;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 95% (DoD 5%) - Descarga: ");
        Serial.print(descargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    // Pausa cuando SOC = 80% (DoD = 20%)
    if (dodLevel == 2 && dod >= 0.2 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        dodLevel = 3;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 80% (DoD 20%) - Descarga: ");
        Serial.print(descargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    // Pausa cuando SOC = 60% (DoD = 40%)
    if (dodLevel == 3 && dod >= 0.4 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        dodLevel = 4;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 60% (DoD 40%) - Descarga: ");
        Serial.print(descargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    // Pausa cuando SOC = 40% (DoD = 60%)
    if (dodLevel == 4 && dod >= 0.6 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        dodLevel = 5;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 40% (DoD 60%) - Descarga: ");
        Serial.print(descargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }

    // Pausa cuando SOC = 20% (DoD = 80%)
    if (dodLevel == 5 && dod >= 0.8 && !pausaActiva) {
        CC(0);
        pausaActiva = true;
        estadoAntesDePausa = state;
        dodLevel = 6;
        state = 6;
        timerPausa = millis();
        Serial.println("");
        Serial.println("========================================");
        Serial.print(">>> PAUSA: SOC 20% (DoD 80%) - Descarga: ");
        Serial.print(descargaAcumulada, 2);
        Serial.println(" mAh");
        Serial.println(">>> Envia 'C' para continuar");
        Serial.println("========================================");
    }


    if (state == 0) {
        if (!cycle) { //solo en el primer ciclo
            if (millis() - timer > 10000) {
                CC(-C); // DESCARGA A -150 mA
                descargaAcumulada = 0;
                dodLevel = 0;
                lastDischargeTime = millis();
                pausaActiva = false;
                state = 1;
            }
        }
    }
    if (state == 1) {
        if (valorVDC <= Vmin) { //CUANDO HAS LLEGADO AL V MIN LIMITE
            CV(Vmin);
            state = 2;
            timer = millis();
            pidControllerV.ForceUpdate(Vmax);
        }
    }
    if (state == 2) {
        if (valorVDC <= Vmin + thres && valorVDC >= Vmin - thres && valorADC <= C_30 && valorADC >= -C_30) {
            if (millis() - timer > 30000) {
                CC(0); //PASA DIRECTAMENTE A REPOSO
                state = 0;
                cycle++;


                Serial.println("");
                Serial.println("========================================");
                Serial.println(">>> DESCARGA COMPLETADA");
                Serial.print(">>> Descarga total: ");
                Serial.print(descargaAcumulada, 2);
                Serial.println(" mAh");
                Serial.print(">>> Voltaje final: ");
                Serial.print(valorVDC, 2);
                Serial.println(" mV");
                Serial.println(">>> Sistema en reposo permanente");
                Serial.println("========================================");
            }
        }
        else {
            timer = millis();
        }
    }
    if (state == 3) {
        if (valorVDC >= Vmax) {
            CV(Vmax); //CUANDO HAS LLEGADO AL V MAX LIMITE
            state = 4;
            timer = millis();
            pidControllerV.ForceUpdate(Vmin);
        }
    }
    if (state == 4) {
        if (valorVDC <= Vmax + thres && valorVDC >= Vmax - thres && valorADC <= C_30 && valorADC >= -C_30) {
            if (millis() - timer > 30000) {
                CC(0); //REPOSO
                state = 5;
            }
        }
        else {
            timer = millis();
        }
    }
    if (state == 5) {
        if (valorVDC <= 3600) {
            CC(0);
            state = 0;
            cycle++;
        }
    }

    // State 6: Estado de pausa
    if (state == 6) {
        if (millis() - timerPausa > 30000) {
            Serial.println(">>> En pausa - Esperando comando 'C'...");
            timerPausa = millis();
        }
    }
}

// pidControllerV.TurnOff();
// mode=1;
// pidControllerI.SetOutputLimits(2180,2245);
// pidControllerI.Setpoint=0;
// pidControllerI.TurnOn();
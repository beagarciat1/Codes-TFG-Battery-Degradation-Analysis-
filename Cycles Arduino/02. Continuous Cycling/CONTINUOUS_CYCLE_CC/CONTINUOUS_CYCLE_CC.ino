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
float T=0;

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


void actualizarCarga() {
    unsigned long tiempoActual = millis();
    float dt = (tiempoActual - lastChargeTime) / 3600000.0; // Convierte ms a horas

    
    cargaAcumulada += valorADC * dt; // mAh

    lastChargeTime = tiempoActual;
}

void get_data() {
    if (Serial.available() > 0) {
        // Leer la cadena del puerto serie
        T=millis();
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
        Serial.print(", Carga_mAh, ");
        Serial.print(cargaAcumulada, 2);

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
    cargaAcumulada = 0;
    socLevel = 0;
    lastChargeTime = millis();
    pausaActiva = false;
    estadoAntesDePausa = 1;

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

}

void loop() {
    
    if (millis() - flag > 50) {
        get_data();
        actualizarCarga();
        flag = millis();
    }

    if (state == 0) {
        if ((millis() - timer > 10000)&(cycle<5)) {
            cargaAcumulada = 0;
            CC(C); // CARGA CC
            state = 1;
            }
    }

    if (state == 1) {
        if (valorVDC >= Vmax) { // Alcanza 4.2V
            if (cycle<74) {
                cargaAcumulada = 0;
                CC(-C); // DESCARGA CC (sin pasar por CV)
                state = 2;
                timer = millis();
                cycle++;
            }
            else {
                state=0;
                CC(0);
                cargaAcumulada = 0;
                cycle++;
            }
            
        }
    }

    if (state == 2) {
        if (valorVDC <= Vmin) { // Alcanza 3.0V
            CC(0); // Reposo
            state = 0;
            timer = millis();
        }
    }

}

// pidControllerV.TurnOff();
// mode=1;
// pidControllerI.SetOutputLimits(2180,2245);
// pidControllerI.Setpoint=0;
// pidControllerI.TurnOn();

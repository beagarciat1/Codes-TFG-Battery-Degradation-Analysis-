#include <PIDController.hpp>
// PID::PIDParameters<double> parametersI_aggresive(0.2, 0.8, 0.01); para 0.5 s
//PID::PIDParameters<double> parametersI_aggresive(0.5, 2, 0.01);
PID::PIDParameters<double> parametersI_aggresive(4, 3.5, 0.01);
PID::PIDParameters<double> parametersI_conservative(4, 3.5, 0.01);
// PID::PIDParametersAdaptative<double> adaptative(10, conservative, 100, aggresive);
PID::PIDController<double> pidControllerI(parametersI_aggresive);

PID::PIDParameters<double> parametersV_aggresive(0.5,5,0);
PID::PIDController<double> pidControllerV(parametersV_aggresive);
const double Vmin=3000;//2500;
const double Vmax=4200;//4300;
const double thres=10;
const double C=150;
const double C_30=C/30;//33.33;

double dacValueV=4095/2.0;
double dacValueI=4095/2.0;

bool mode=1;
int state = 0;
int N=5;
int cycle = 0;
const int PIN_OUTPUT=A0;
float valorVDC=0;
float valorADC=0;
//const double wait_time=7200000; //7200000
unsigned int timer=millis();
//unsigned int timer2=millis();
unsigned int flag=millis();

void CC (double Crate) {
  pidControllerV.TurnOff();
  mode=1;
  if (Crate>0.1) pidControllerI.SetOutputLimits(4095/2-100,4095);
  else if (Crate<-0.1) pidControllerI.SetOutputLimits(0,4095/2+100);
  else pidControllerI.SetOutputLimits(4095/2-100,4095/2+100);
  pidControllerI.Setpoint=Crate;
  pidControllerI.TurnOn();
}
void CV (double Vref) {
  int limit= (int )dacValueI;
  pidControllerI.TurnOff();
  mode=0;
  if (Vref==Vmax) pidControllerV.SetOutputLimits(4095/2-100,limit);
  else if (Vref==Vmin)pidControllerV.SetOutputLimits(limit,4095+100);
  pidControllerV.Setpoint=Vref;
  pidControllerV.TurnOn();
}

void get_data() {
   if (Serial.available()>0) {
    // Leer la cadena del puerto serie
    String data = Serial.readStringUntil('\n');
    // Serial.print("Arduino:  " + data);
    Serial.print(", Ciclo, ");
    Serial.print(cycle);
    // Convertir la cadena en números decimales
    float valorADC2 = atof(data.substring(0, data.indexOf(" ADC")).c_str());
    float valorVDC2 = atof(data.substring(data.lastIndexOf(",") + 1, data.indexOf(" VDC")).c_str());
    // Imprimir los valores
    valorADC=-valorADC2*1000;
    valorVDC=valorVDC2*1000;
    Serial.print(", State, ");
    Serial.print(state);
    Serial.print(", Valor_VDC, ");
    Serial.print(valorVDC, 6); // Imprimir con 5 decimales de precisión
    Serial.print(", Valor_ADC, ");
    Serial.print(valorADC, 6);
    
    // put your main code here, to run repeatedly:
    // int dacValue = (2.5+pidControllerI.Output/500 )/5 * (4096 - 1);
    if (mode) {
      if (valorADC>pidControllerI.Setpoint-thres && valorADC<pidControllerI.Setpoint+thres) {
        pidControllerI.SetTunings(parametersI_conservative);
        pidControllerI.Input = valorADC;
        pidControllerI.Update();
      }
      dacValueI=pidControllerI.Output;
      Serial.print(", DAC, ");
      Serial.println(dacValueI, 6);
      analogWrite(PIN_OUTPUT, (int) dacValueI);
      
    }
    else {
      pidControllerV.SetTunings(parametersV_aggresive);
      pidControllerV.Input = valorVDC;
      pidControllerV.Update();
      dacValueV=pidControllerV.Output;
      Serial.print(", DAC, ");
      Serial.println(dacValueV, 6);
      analogWrite(PIN_OUTPUT, (int) dacValueV);

    }

  }
  if (mode) { //se ejecuta cada vez que se llama a get_data, llegue un dato o no
    if (valorADC<pidControllerI.Setpoint-thres || valorADC>pidControllerI.Setpoint+thres) {
      pidControllerI.SetTunings(parametersI_aggresive);
      pidControllerI.Input = valorADC;
      pidControllerI.Update();
    }
  } 

}


void setup() {
  Serial.begin(9600);
  delay(5000);
  analogWrite(PIN_OUTPUT, 4095/2);
  //Serial.setTimeout(1);
  analogWriteResolution(12);
  pidControllerI.SetOutputLimits(0,4095);
  pidControllerV.SetOutputLimits(1700,3300);
  pidControllerI.SetOutputLimits(4095/2-20,4095/2+20);
  pidControllerI.Setpoint= 0;
  pidControllerV.Setpoint= Vmin;     // The "goal" the PID controller tries to "reach"  // Tune the PID, arguments: kP, kI, kD
  //pidControllerI.TurnOn();
  pidControllerV.TurnOff();
  pidControllerI.TurnOn();
  analogWrite(PIN_OUTPUT, 4095/2);
  mode=1;

  cycle=0;
  timer=millis();
  flag=millis();
  state=0;

}

void loop() {
  if (millis()-flag>50) {
    get_data();
    flag=millis();
  }
  if (state==0) {
    if(!cycle){
      if(millis()-timer>10000){
        CC(C/5);
        state=1;
      }
    }
  }
  if (state==1){
    if (valorVDC>=Vmax){
      CV(Vmax);
      state=2;  
      timer=millis();   
      pidControllerV.ForceUpdate(Vmin);
    }
  }

  if (state==2) {
    if (valorVDC<=Vmax+thres && valorVDC>=Vmax-thres && valorADC<=C_30/1.5 && valorADC>=-C_30/1.5) {
      if (millis()-timer>30000) {
        CC(-C_30);
        state=3;
      }
    } else {
      timer=millis();
    }
  }
  if (state==3){
    if (valorVDC<=Vmin){
      CC(C_30);
      state=4;     
      timer=millis();
    }
  }
  if (state==4){
    if (valorVDC>=Vmax){
      CC(0);
      state=5;  
      timer=millis();   
    }
  }
  if (state==5) {
    if (valorVDC<=3600 || valorVDC<=4400) {
      CC(0);
      state=0;
      cycle++;
      }
  }
}

// pidControllerV.TurnOff();
// mode=1;
// pidControllerI.SetOutputLimits(2180,2245);
// pidControllerI.Setpoint=0;
// pidControllerI.TurnOn();
const int Pumppin = 10; // using pin3 to read the output 
//const long offDuration = 600;// OFF time for Pump
//const long onDuration = 400;// ON time for Pump
const long phaseone = 400; //first heart beat
const long phasetwo = 100; //lag
const long phasethree =  150; //dicrotic notch
const long phasefour = 250; //chill
int PumpState =0;// initial state of Pump
int PumpStr = 0; //voltage

long rememberTime=0;// this is used by the code

void setup()
{
  Serial.begin(115200); // For serial communication with the computer.
  pinMode(Pumppin,OUTPUT);// define Pumppin as output
  analogWrite(Pumppin,PumpState);// set initial state which is 0V (off).
}

void loop()
{
 if( PumpState == 0 )
 {
    if( (millis()- rememberTime) >= phasefour) // once millis reach 350ms of 0V it will switch to onmode with preset voltage
    {   
    PumpState = 1;// change the state of Pump
    PumpStr = 60; //turn on
    rememberTime=millis();// remember Current millis() time
    }
 }
 else if( PumpState == 1) 
 {
    if( (millis()- rememberTime) >= phaseone) //stay on for 550ms
    {
    PumpState = 2;
    PumpStr = 20; //turn off
    rememberTime=millis();
    }
 }
 else if( PumpState == 2)
 {
    if( (millis()- rememberTime) >= phasetwo) //stay off for 25ms
    {
    PumpState = 3;
    PumpStr = 40; //turn on
    rememberTime=millis();
    }
 }
 else 
 {   
    if( (millis()- rememberTime) >= phasethree) //stay on for 100ms
    {     
    PumpState = 0; //reset if loop to first one
    PumpStr = 0; //turn off
    rememberTime=millis();// remember Current millis() time
    }
 }

 analogWrite(Pumppin,PumpStr);// turn the pump ON or OFF
 float voltage = PumpStr *5/255;
 Serial.println(voltage); // Monitoring the volatage output of the pin 
}// loop ends
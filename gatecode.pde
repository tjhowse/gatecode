/*
  Gatecode
  
 */

#include <EEPROM.h>
//#include "eepromanything.h"
#define NO_MAGNET 505
#define NO_MAGNET_DEADBAND 5
#define O_C_FLIPPER 0

#define TEENSY

#ifdef TEENSY
	#define PIN_HALL A0
	#define PIN_MOTOR0 0
	#define PIN_MOTOR1 1
	#define PIN_BUTTON 2
	#define PIN_BUZZER 3
	#define PIN_REMOTEA 4
	#define PIN_REMOTEB 5
	#define PIN_REMOTEC 6
	#define PIN_REMOTED 7
#else
	#define PIN_HALL A0
	#define PIN_MOTOR0 2
	#define PIN_MOTOR1 3
	#define PIN_BUTTON 12
	#define PIN_BUZZER 13
#endif

#define BUTTON_OPEN PIN_REMOTEA
#define BUTTON_CLOSE PIN_REMOTEC
#define BUTTON_BUZZ PIN_REMOTED
#define BUTTON_STOP PIN_REMOTEB

#define BUZZ_DURATION 1000

#define MAGNET_MASK_DURATION 1000

#define OPEN_TIMEOUT 15000
#define CLOSE_TIMEOUT 15000

#define HALFWAY 2
#define OPEN 1
#define CLOSED 0

//#define DOTLCOUNT 300000
#define DOTLCOUNT 5000
#define DOTLATTEMPTLIMIT 2

#define MOTOR_POLARITY LOW

int hallVal;
unsigned long moveStartTime;
unsigned long dotl_time;
int gate_position;
int prev_gate_position;
int move_direction;
int remote_button;
int dotl_attempts;
int i;

void setup()
{
        int low, high;
	pinMode(PIN_BUZZER, OUTPUT);
	pinMode(PIN_MOTOR0, OUTPUT);
	pinMode(PIN_MOTOR1, OUTPUT);
	pinMode(PIN_BUTTON, INPUT);
	pinMode(PIN_HALL, INPUT);
	pinMode(PIN_REMOTEA, INPUT);
	pinMode(PIN_REMOTEB, INPUT);
	pinMode(PIN_REMOTEC, INPUT);
	pinMode(PIN_REMOTED, INPUT);	

	digitalWrite(PIN_BUTTON, HIGH);
        digitalWrite(PIN_REMOTEA, HIGH);
        digitalWrite(PIN_REMOTEB, HIGH);
        digitalWrite(PIN_REMOTEC, HIGH);
        digitalWrite(PIN_REMOTED, HIGH);
	Serial.begin(9600);

        buzz(300);
        delay(100);
        buzz(100);
        delay(100);
        buzz(400);
}

void loop()
{
	if (is_button())
	{
		if (gate_position == CLOSED)
		{
			open_gate();
		} else if (gate_position == OPEN) {
			close_gate();
		} else {
			// If the gate is stuck halfway, drive in a direction opposite to the
			// previous travel
			if (move_direction == OPEN)
			{
				open_gate();
			} else {
				close_gate();
			}
		}
	}
	check_remote();
	//check_dotl();
	//set_close();
	update_gate_position();
	delay(50);
}

void open_gate()
{
	if (gate_position == OPEN) return;
	Serial.println("Opening gate");
	buzz(BUZZ_DURATION);
	set_open();
	moveStartTime = millis();
	delay(MAGNET_MASK_DURATION);
	while (1)
	{
		if (is_magnet())
		{
			Serial.println("Stopped: Magnet");
                	set_free();
			buzz(300);
                        break;
		}
		if ((millis() - moveStartTime) > OPEN_TIMEOUT)
		{
			Serial.println("Stopped: Timeout");
			moveStartTime = 0;
			break;
		}
		if (is_button())
		{
			Serial.println("Stopped: Button");
			move_direction = CLOSED;
			break;
		}
		if (is_remote_stop())
		{
			Serial.println("Stopped: Remote");
			move_direction = CLOSED;
			break;
		}
		delay(50);
	}
	set_free();
	update_gate_position();
	delay(1000);
}

void close_gate()
{
	if (gate_position == CLOSED) return;
	Serial.println("Closing gate");
	buzz(BUZZ_DURATION);
	set_close();
	moveStartTime = millis();
	delay(MAGNET_MASK_DURATION);
	while (1)
	{
		if (is_magnet())
		{
			Serial.println("Stopped: Magnet");
                	set_free();
			buzz(300);
			break;
		}
		if ((millis() - moveStartTime) > CLOSE_TIMEOUT)
		{
			Serial.println("Stopped: Timeout");
			moveStartTime = 0;
			break;
		}
		if (is_button())
		{
			Serial.println("Stopped: Button");
			move_direction = OPEN;
			break;
		}
		if (is_remote_stop())
		{
			Serial.println("Stopped: Remote");
			move_direction = OPEN;
			break;
		}
		delay(50);
	}
	set_free();
	update_gate_position();
	delay(1000);
}

void buzz(int duration)
{
	digitalWrite(PIN_BUZZER, HIGH);
	delay(duration);
	digitalWrite(PIN_BUZZER, LOW);
}

void set_open()
{
	move_direction = OPEN;
	digitalWrite(PIN_MOTOR0, MOTOR_POLARITY);
	digitalWrite(PIN_MOTOR1, !MOTOR_POLARITY);
}

void set_close()
{
	move_direction = CLOSED;
	digitalWrite(PIN_MOTOR0, !MOTOR_POLARITY);
	digitalWrite(PIN_MOTOR1, MOTOR_POLARITY);
}

void set_free()
{
	digitalWrite(PIN_MOTOR0, !MOTOR_POLARITY);
	digitalWrite(PIN_MOTOR1, !MOTOR_POLARITY);
}

void set_brake()
{
	digitalWrite(PIN_MOTOR0, MOTOR_POLARITY);
	digitalWrite(PIN_MOTOR1, MOTOR_POLARITY);
}

int is_button()
{
	return !digitalRead(PIN_BUTTON);
}

int check_remote()
{
	if (!digitalRead(BUTTON_STOP))
	{
                Serial.println("Remote: Stop");
		set_free();
	} else if (!digitalRead(BUTTON_CLOSE)) {
                Serial.println("Remote: Close");
		close_gate();
	} else if (!digitalRead(BUTTON_OPEN)) {
                Serial.println("Remote: Open");
		open_gate();
	} else if (!digitalRead(BUTTON_BUZZ)) {
                Serial.println("Remote: Buzz");
		buzz(BUZZ_DURATION);
	}
}
int is_remote_stop()
{
	// Checks to see if button B is pressed
	return !digitalRead(BUTTON_STOP);
}
	
int is_closed()
{
	return ((is_magnet()-1) == CLOSED);
}

int is_open()
{
	return ((is_magnet()-1) == OPEN);
}

void check_dotl()
{
	if (((dotl_time-millis()) > DOTLCOUNT) && (dotl_attempts <= DOTLATTEMPTLIMIT))
	{
		close_gate();
		dotl_time = millis();
		dotl_attempts++;
	}
}

void update_gate_position()
{
	prev_gate_position = gate_position;
	if (is_open())
	{
		gate_position = OPEN;
	} else if (is_closed()) {
		gate_position = CLOSED;
	} else {
		gate_position = HALFWAY;
	}
	
	if (prev_gate_position != gate_position)
	{
		switch(gate_position)
		{
			case OPEN:
				Serial.println("Gate is open");
				break;
			case CLOSED:
				Serial.println("Gate is closed");
				dotl_time = 0;
				dotl_attempts = 0;
				break;
			case HALFWAY:
				Serial.println("Gate is halfway");
				break;
		}
	}
	if ((prev_gate_position == CLOSED) && (gate_position != CLOSED))
	{
		dotl_time = millis();
	}
}

int is_magnet()
{
	hallVal = analogRead(PIN_HALL);
	Serial.println(hallVal, DEC);

	if (hallVal > (NO_MAGNET+NO_MAGNET_DEADBAND))		
	{
		return O_C_FLIPPER+1;
	} else if (hallVal < (NO_MAGNET-NO_MAGNET_DEADBAND)) {
		return !O_C_FLIPPER+1;
	} else {
		return 0;
	}
}

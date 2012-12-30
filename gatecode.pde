/*
  Gatecode
  
 */

#define NO_MAGNET 506
#define NO_MAGNET_DEADBAND 3
#define O_C_FLIPPER 1

#define TEENSY

#ifdef TEENSY
	#define PIN_HALL A0
	#define PIN_MOTOR0 0
	#define PIN_MOTOR1 1
	#define PIN_BUTTON 2
	#define PIN_BUZZER 3
#else
	#define PIN_HALL A0
	#define PIN_MOTOR0 2
	#define PIN_MOTOR1 3
	#define PIN_BUTTON 12
	#define PIN_BUZZER 13
#endif

#define BUZZ_DURATION 1000

#define MAGNET_MASK_DURATION 1000

#define OPEN_TIMEOUT 10000
#define CLOSE_TIMEOUT 10000

#define HALFWAY 2
#define OPEN 1
#define CLOSED 0


#define MOTOR_POLARITY HIGH

int hallVal;
unsigned long moveStartTime;
int gate_position;
int prev_gate_position;
int move_direction;

void setup()
{
	pinMode(PIN_BUZZER, OUTPUT);
	pinMode(PIN_MOTOR0, OUTPUT);
	pinMode(PIN_MOTOR1, OUTPUT);
	pinMode(PIN_BUTTON, INPUT);
	pinMode(PIN_HALL, INPUT);
	
	digitalWrite(PIN_BUTTON, HIGH);
	Serial.begin(9600);
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
			if (move_direction == CLOSED)
			{
				open_gate();
			} else {
				close_gate();
			}
		}
	}
	//set_close();
	update_gate_position();
	delay(50);
}

void open_gate()
{
	if (gate_position == OPEN) return;
	Serial.println("Opening gate");
	buzz();
	set_open();
	moveStartTime = millis();
	delay(MAGNET_MASK_DURATION);
	while (1)
	{
		if (is_magnet())
		{
			Serial.println("Stopped: Magnet");
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
	buzz();
	set_close();
	moveStartTime = millis();
	delay(MAGNET_MASK_DURATION);
	while (1)
	{
		if (is_magnet())
		{
			Serial.println("Stopped: Magnet");
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
		delay(50);
	}
	set_free();
	update_gate_position();
	delay(1000);
}

void buzz()
{
	digitalWrite(PIN_BUZZER, HIGH);
	delay(BUZZ_DURATION);
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

int is_closed()
{
	return ((is_magnet()-1) == CLOSED);
}

int is_open()
{
	return ((is_magnet()-1) == OPEN);
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
				break;
			case HALFWAY:
				Serial.println("Gate is halfway");
				break;
		}
	}	
}

int is_magnet()
{
	hallVal = analogRead(A0);
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
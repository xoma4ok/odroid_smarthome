CC=g++
CFLAG=-g
OBJGROUP=bme280.o bme280-i2c.o si1132.o odroid_smarthome.o

all: odroid_smarthome

weather_board: $(OBJGROUP)
	$(CC) -o odroid_smarthome $(OBJGROUP) -lm -lpq -lpqxx

clean:
	rm *o odroid_smarthome

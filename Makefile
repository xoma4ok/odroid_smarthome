CC=g++
CFLAG=-g
OBJGROUP=bme280.o bme280-i2c.o si1132.o odroid_smarthome.o

all: odroid_smarthome

odroid_smarthome: $(OBJGROUP)
	$(CC) -o odroid_smarthome $(OBJGROUP) -lm -lpq -lpqxx -lcurl

clean:
	rm *o odroid_smarthome

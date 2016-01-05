#include <stdio.h> 
#include "bme280-i2c.h"
#include "si1132.h"
#include <cstdio> 
#include <iostream>
#include <unistd.h>
#include <pqxx/pqxx>

using namespace std;
using namespace pqxx;

static u32 pressure_hpa;
static u32 pressure_mmhg;
static s32 temperature;
static u32 humidity;
static float altitude;

float SEALEVELPRESSURE_HPA = 1024.25;

int main(int argc, char **argv) {

	/*
	 [::]
	 Блок настройки
	 */
	const char* device;
	device = "/dev/i2c-1";
	int l_timer = 60000000; //Как часто опрашиваем датчики и бегаем по циклу. По дефолту 60 секунд
	int l_count_current = 1; //Текущий счетчик
	int l_count_for_commit_to_base = 1; //На какой итерации мы коммитим в базу. 1=каждый раз
//	int l_count_for_send_narodmon = 1; //На какой итерации мы сливаем на сайт(заготовка). 1=каждый раз
	connection C(
			"dbname=smarthome user=postgres password=odroid \
      hostaddr=127.0.0.1 port=5432");
	/* Create prepared SQL statement */
	C.prepare("insert_item",
			"INSERT INTO sensor_items (sensor_id,value_number) VALUES ($1, $2 )");
	/*
	 [::]
	 */
	if (argc == 2) {
		device = argv[1];
	} else if (argc > 2) {
		printf("Usage :\n");
		printf("sudo ./weather_board [i2c node](default \"/dev/i2c-1\")\n");
		return -1;
	}
	if (C.is_open()) {
		cout << "Opened database successfully: " << C.dbname() << endl;
	} else {
		cout << "Can't open database" << endl;
		return 1;
	}
	si1132_begin(device);
	bme280_begin(device);
	while (1) {
		l_count_current++;
		printf("======== si1132 ========\n");
		printf("UV_index : %.2f\n", Si1132_readUV() / 100.0);
		printf("Visible : %.0f Lux\n", Si1132_readVisible());
		printf("IR : %.0f Lux\n", Si1132_readIR());
		bme280_read_pressure_temperature_humidity(&pressure_hpa, &temperature,
				&humidity);
		printf("======== bme280 ========\n");
		printf("temperature : %.2lf 'C\n", (double) temperature / 100.0);
		printf("humidity : %.2lf %%\n", (double) humidity / 1024.0);
		printf("pressure hpa : %.2lf hPa\n", (double) pressure_hpa / 100.0);
		pressure_mmhg = (pressure_hpa / 100.0) * 0.7500637554192;
		printf("pressure mmhg : %.2lf mmHg\n", (double) pressure_mmhg);
		printf("altitude : %f m\n",
				bme280_readAltitude(pressure_hpa, SEALEVELPRESSURE_HPA));
		if (l_count_current % l_count_for_commit_to_base == 0) {
			/* Инсертим в базу*/
			try {
				/* Create a transactional object. */
				work W(C);
				/* Execute prepared SQL query */
				W.prepared("insert_item")(1)(temperature / 100.0).exec(); //bme280 temp
				W.prepared("insert_item")(2)(humidity / 1024.0).exec(); //bme280 hum
				//уберем неправославные единицы W.prepared("insert_item")(3)(pressure_hpa / 100.0).exec(); //bme280 pressure_hpa
				//уберем лишнее W.prepared("insert_item")(4)(bme280_readAltitude(pressure_hpa, SEALEVELPRESSURE_HPA)).exec(); //bme280 altitude
				W.prepared("insert_item")(5)(Si1132_readUV() / 100.0).exec(); //si1132 uv index
				W.prepared("insert_item")(6)(Si1132_readVisible()).exec(); //si1132 visible
				W.prepared("insert_item")(7)(Si1132_readIR()).exec(); //si1132 IR
				W.prepared("insert_item")(8)(pressure_mmhg).exec(); //bme280 pressure_mmhg
				W.commit();
				cout << "Records inserted successfully\n" << endl;
			} catch (const std::exception &e) {
				cout << "Error at inserting to local postgreSQL database\n" << endl;
				cerr << e.what() << std::endl;
				return 1;
			}
		}
		usleep(l_timer);
		if (l_count_current == 2000000000) {
			l_count_current = 0;
		}
	}

	C.disconnect();
	return 0;
}


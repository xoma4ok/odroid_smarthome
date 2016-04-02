﻿#include <stdio.h>
#include "bme280-i2c.h"
#include "si1132.h"
#include <cstdio>
#include <iostream>
#include <unistd.h>
#include <pqxx/pqxx> //Библиотека для работы с PostgreSQL
#include "curl/curl.h" //CURL
#include <cstring>
#include <string>

using namespace std;
using namespace pqxx;

static u32 pressure_hpa;
static u32 pressure_mmhg;
static s32 temperature;
static u32 humidity;
static float altitude;

float SEALEVELPRESSURE_HPA = 1024.25;

int main(int argc, char **argv)
{
  /*
   [::]
   Блок настройки
   */
  const char* l_device;
  l_device = "/dev/i2c-1";
  int g_timer; //Как часто опрашиваем датчики и бегаем по циклу. По дефолту 60 секунд =60000000
  int l_count_current = 1; //Текущий счетчик
  int l_count_for_commit_to_base = 1; //На какой итерации мы коммитим в базу. 1=каждый раз
  int l_count_for_send_narodmon = 5; //На какой итерации мы сливаем на сайт. 5=Каждый 5ый раз, по дефолту раз в 5 минут
  string l_send_string_mac_prefix;
  string l_send_string_address;
  string l_send_payload;
  ostringstream l_buffer_for_double;
  connection C_postgres(
    "dbname=smarthome user=postgres password=odroid \
      hostaddr=127.0.0.1 port=5432");
  /* Create prepared SQL statement */
  C_postgres.prepare("insert_sensor_item",
                     "INSERT INTO sensor_items (sensor_id,value_number) VALUES ($1, $2 )");
  C_postgres.prepare("select_config_param_char",
                     "SELECT t.attr_char FROM smarthome_config t where upper(t.attr_name) = upper($1) ");
  C_postgres.prepare("select_config_param_num",
                     "SELECT t.attr_num FROM smarthome_config t where upper(t.attr_name) = upper($1) ");
  /* Create a transactional object. */
  work W_postgres_config(C_postgres);
  result R_postgres;
  /*
   [::]
   Заполняем кофигурацию из базы
   ====================
   */
  R_postgres = W_postgres_config.prepared("select_config_param_num")("g_timer_sec").exec();
  g_timer = R_postgres[0][0].as<int>() * 1000000;
  R_postgres = W_postgres_config.prepared("select_config_param_char")("narodmon_mac").exec();
  l_send_string_mac_prefix = R_postgres[0][0].c_str();
  R_postgres = W_postgres_config.prepared("select_config_param_char")("narodmon_post_address").exec();
  l_send_string_address = R_postgres[0][0].c_str();
  W_postgres_config.commit();
  /*
  ====================
  */
  if(argc == 2)
    {
      l_device = argv[1];
    }
  else if(argc > 2)
    {
      printf("Usage :\n");
      printf("sudo ./weather_board [i2c node](default \"/dev/i2c-1\")\n");
      return -1;
    }
  if(C_postgres.is_open())
    {
      cout << "Opened database successfully: " << C_postgres.dbname() << endl;
    }
  else
    {
      cout << "Can't open database" << endl;
      return 1;
    }
  si1132_begin(l_device);
  bme280_begin(l_device);
  while(1)
    {
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
      //Коммит в локальную базу
      if(l_count_current % l_count_for_commit_to_base == 0)
        {
          /* Инсертим в базу*/
          try
            {
              /* Create a transactional object. */
              work W_postgres(C_postgres);
              /* Execute prepared SQL query */
              W_postgres.prepared("insert_sensor_item")(1)(temperature / 100.0).exec(); //bme280 temp
              W_postgres.prepared("insert_sensor_item")(2)(humidity / 1024.0).exec(); //bme280 hum
              //уберем неправославные единицы W.prepared("insert_sensor_item")(3)(pressure_hpa / 100.0).exec(); //bme280 pressure_hpa
              //уберем лишнее W.prepared("insert_sensor_item")(4)(bme280_readAltitude(pressure_hpa, SEALEVELPRESSURE_HPA)).exec(); //bme280 altitude
              W_postgres.prepared("insert_sensor_item")(5)(Si1132_readUV() / 100.0).exec(); //si1132 uv index
              W_postgres.prepared("insert_sensor_item")(6)(Si1132_readVisible()).exec(); //si1132 visible
              W_postgres.prepared("insert_sensor_item")(7)(Si1132_readIR()).exec(); //si1132 IR
              W_postgres.prepared("insert_sensor_item")(8)(pressure_mmhg).exec(); //bme280 pressure_mmhg
              W_postgres.commit();
              cout << "Records inserted successfully" << endl;
            }
          catch(const std::exception &e)
            {
              cout << "Error at inserting to local postgreSQL database" << endl;
              cerr << e.what() << endl;
              return 1;
            }
        }
      //Отправляем значения в сервис Narodmon.ru
      if(l_count_current % l_count_for_send_narodmon == 0)
        {
          try
            {
              cout << "Starting HTTP POST to " << l_send_string_address.c_str() << endl;
              CURL *curl;
              CURLcode curl_res;
              curl = curl_easy_init();
              cout << "CURL inited" << endl;
              l_send_payload = ("ID=");
              l_send_payload += l_send_string_mac_prefix;
              l_buffer_for_double << (temperature / 100.0);
              l_send_payload = l_send_payload + "&BME280TEMP=" + l_buffer_for_double.str();
              l_buffer_for_double.str("");
              l_buffer_for_double.clear();
              l_buffer_for_double << (humidity / 1024.0);
              l_send_payload = l_send_payload + "&BME280HUM=" + l_buffer_for_double.str();
              l_buffer_for_double.str("");
              l_buffer_for_double.clear();
              l_buffer_for_double << pressure_mmhg;
              l_send_payload = l_send_payload + "&BME280PRESS=" + l_buffer_for_double.str();
              l_buffer_for_double.str("");
              l_buffer_for_double.clear();
              l_buffer_for_double << (Si1132_readUV() / 100.0);
              l_send_payload = l_send_payload + "&SI1132UV=" + l_buffer_for_double.str();
              l_buffer_for_double.str("");
              l_buffer_for_double.clear();
              l_buffer_for_double << (Si1132_readVisible());
              l_send_payload = l_send_payload + "&SI1132VISIBLE=" + l_buffer_for_double.str();
              l_buffer_for_double.str("");
              l_buffer_for_double.clear();
              l_buffer_for_double << (Si1132_readIR());
              l_send_payload = l_send_payload + "&SI1132IR=" +  l_buffer_for_double.str();
              l_buffer_for_double.str("");
              l_buffer_for_double.clear();
              cout << "CURL payload =" << l_send_payload.c_str() << endl;
              if(curl)
                {
                  curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
                  curl_easy_setopt(curl, CURLOPT_URL, l_send_string_address.c_str());
                  curl_easy_setopt(curl, CURLOPT_POST, 1);
                  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10); //10 сек таймаут т.к. иногда работаем через EDGE/3g
                  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, l_send_payload.c_str());
                  curl_res = curl_easy_perform(curl);
                  curl_easy_cleanup(curl);
                }
            }
          catch(const std::exception &e)
            {
              cout << "Error at HTTP POST" << endl;
              cerr << e.what() << endl;
              return 1;
            }
        }
      usleep(g_timer);
      if(l_count_current == 2000000000)
        {
          l_count_current = 0;
        }
    }
  C_postgres.disconnect();
  return 0;
}

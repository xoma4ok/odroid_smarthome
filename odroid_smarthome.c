#include <stdio.h>
#include "bme280-i2c.h"
#include "si1132.h"
#include <cstdio>
#include <iostream>
#include <unistd.h>
#include <pqxx/pqxx> //Библиотека для работы с PostgreSQL
#include "curl/curl.h" //CURL
#include <cstring>
#include <string>
#include <dirent.h>
#include <fcntl.h>
#include <stdlib.h>

using namespace std;
using namespace pqxx;

static u32 pressure_hpa;
static u32 pressure_mmhg;
static s32 temperature;
static u32 humidity;
static float altitude;

float SEALEVELPRESSURE_HPA;

int g_timer; //Как часто опрашиваем датчики и бегаем по циклу. По дефолту 60 секунд =60000000
int g_count_for_commit_to_base ; //На какой итерации мы коммитим в базу. 1=каждый раз = 1
int g_count_for_cleanup_db ; //На какой итерации мы чистим базу
int g_count_for_send_narodmon; //На какой итерации мы сливаем на сайт. 5=Каждый 5ый раз, по дефолту раз в 5 минут = 5
string l_send_string_mac_prefix;
string l_send_string_address;
//Для ds18b20
DIR *g_dir;
struct dirent *g_dirent;
char g_ds18_buf[256];     // Data from device
char g_ds18_tmpData[5];   // Temp C * 1000 reported by device
const char g_ds18_path[] = "/sys/bus/w1/devices";
int g_devCnt = 0;
ssize_t g_numRead;
//---

void prepare_sql(pqxx::connection_base &p_connection)
{
  /*
  Подготавливаем типовые запросы
  */
  p_connection.prepare("insert_sensor_item",
                       "INSERT INTO sensor_items (record_type,sensor_id,value_number) VALUES (1, $1, $2 )");
  p_connection.prepare("select_config_param_char",
                       "SELECT t.attr_char FROM smarthome_config t where upper(t.attr_name) = upper($1) ");
  p_connection.prepare("select_config_param_num",
                       "SELECT t.attr_num FROM smarthome_config t where upper(t.attr_name) = upper($1) ");
  p_connection.prepare("cleanup_base", "SELECT p_cleanup()");
  p_connection.prepare("get_ds18_sensor_id", "SELECT f_get_ds18_sensor_id($1)");
}

void load_config_from_db(pqxx::connection_base &p_connection)
{
  /*
  Грузим конфиг и константы из БД
  */
  work W_postgres(p_connection);
  result R_postgres;
  //=====================================================================================
  //Блок общих параметров
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_num")("g_timer_sec").exec();
      g_timer = R_postgres[0][0].as<int>() * 1000000;
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = g_timer_sec" << endl;
      cerr << e.what() << endl;
    }
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_num")("g_local_commit_tic").exec();
      g_count_for_commit_to_base = R_postgres[0][0].as<int>();
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = g_local_commit_tic" << endl;
      cerr << e.what() << endl;
    }
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_num")("g_cleanup_tic").exec();
      g_count_for_cleanup_db = R_postgres[0][0].as<int>();
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = g_count_for_cleanup_db" << endl;
      cerr << e.what() << endl;
    }
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_num")("g_SEALEVELPRESSURE_HPA").exec();
      SEALEVELPRESSURE_HPA = R_postgres[0][0].as<float>();
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = g_SEALEVELPRESSURE_HPA" << endl;
      cerr << e.what() << endl;
    }
  //=====================================================================================
  //Теперь блок для narodmon
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_char")("narodmon_mac").exec();
      l_send_string_mac_prefix = R_postgres[0][0].c_str();
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = narodmon_mac" << endl;
      cerr << e.what() << endl;
    }
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_char")("narodmon_post_address").exec();
      l_send_string_address = R_postgres[0][0].c_str();
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = narodmon_post_address" << endl;
      cerr << e.what() << endl;
    }
  try
    {
      R_postgres = W_postgres.prepared("select_config_param_num")("narodmon_tic_num").exec();
      g_count_for_send_narodmon = R_postgres[0][0].as<int>();
    }
  catch(const std::exception &e)
    {
      cout << "Error at selecting configure parameter = narodmon_tic_num" << endl;
      cerr << e.what() << endl;
    }
  //убиваем транзакционный объект
  W_postgres.commit();
}





int main(int argc, char **argv)
{
  /*
   [::]
   Блок настройки
   */
  const char* l_device;
  l_device = "/dev/i2c-1";
  int l_count_current = 1; //Текущий счетчик
  string l_send_payload;
  ostringstream l_buffer_for_double;
  connection C_postgres(
    "dbname=smarthome user=postgres password=odroid hostaddr=127.0.0.1 port=5432");
//Подготавливаем типовые запросы
  prepare_sql(C_postgres);
//Грузим конфиг и константы из БД
  load_config_from_db(C_postgres);
///
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
  //Начинаем инциализацю 1wire
  cout << "Starting 1-wire initialize" << endl;
  /*
  Ищем сенсоры ds18b20, считаем количество
  */
  int i = 0;
  // 1st pass counts devices
  g_dir = opendir(g_ds18_path);
  if(g_dir != NULL)
    {
      while((g_dirent = readdir(g_dir)))
        {
          // 1-wire devices are links beginning with 28-
          if(g_dirent->d_type == DT_LNK &&
              strstr(g_dirent->d_name, "28-") != NULL)
            {
              i++;
            }
        }
      (void) closedir(g_dir);
    }
  else
    {
      cerr << "Couldn't open the w1 devices directory" << endl;
    }
  g_devCnt = i;
  cout << "Found 1-wire devices: " << g_devCnt << endl;
  i = 0;
  char ds18dev[g_devCnt][16];
  char ds18devPath[g_devCnt][128];
  int ds18dev_sensor_id[g_devCnt];
  char ds18_buf[256];     // Data from device
  char ds18_tmpData[5];   // Temp C * 1000 reported by device
  float ds18_sensor_temp[g_devCnt];
  if(g_devCnt > 0)
    {
      g_dir = opendir(g_ds18_path);
      /* Create a transactional object. */
      work W_postgres(C_postgres);
      result R_postgres;
      cout << "Filing 1-wire masive"  << endl;
      if(g_dir != NULL)
        {
          while((g_dirent = readdir(g_dir)))
            {
              // 1-wire devices are links beginning with 28-
              if(g_dirent->d_type == DT_LNK &&
                  strstr(g_dirent->d_name, "28-") != NULL)
                {
                  strcpy(ds18dev[i], g_dirent->d_name);
                  // Assemble path to OneWire device
                  sprintf(ds18devPath[i], "%s/%s/w1_slave", g_ds18_path, ds18dev[i]);
                  R_postgres = W_postgres.prepared("get_ds18_sensor_id")(ds18dev[i]).exec();
                  ds18dev_sensor_id[i] = R_postgres[0][0].as<int>();
                  cout << "ds18dev name = " << ds18dev[i] << " ds18devPath = " << ds18devPath[i] << " ds18dev_sensor_id= " << ds18dev_sensor_id[i] << endl;
                  i++;
                }
            }
          (void) closedir(g_dir);
        }
      else
        {
          cerr << "Couldn't open the w1 devices directory" << endl;
        }
      cout << "1-wire masive filed successfully"  << endl;
      i = 0;
      W_postgres.commit();
    }
  //конец 1wire
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
      ////Вычитаем значения из 1-wire
      if(g_devCnt > 0)
        {
          while(1)
            {
              int fd = open(ds18devPath[i], O_RDONLY);
              if(fd == -1)
                {
                  cerr << "Couldn't open the w1 device." << endl;;
                }
              while((g_numRead = read(fd, ds18_buf, 256)) > 0)
                {
                  strncpy(ds18_tmpData, strstr(ds18_buf, "t=") + 2, 6);
                  ds18_sensor_temp[i] = strtof(ds18_tmpData, NULL) / 1000;
                }
              close(fd);
              i++;
              if(i == g_devCnt)
                {
                  i = 0;
                  break;
                }
            }
        }
      i = 0;
///
      //Коммит в локальную базу
      if(l_count_current % g_count_for_commit_to_base == 0)
        {
          /* Инсертим в базу*/
          try
            {
              /* Create a transactional object. */
              work W_postgres(C_postgres);
              /* Execute prepared SQL query */
              W_postgres.prepared("insert_sensor_item")(1)(temperature / 100.0).exec(); //bme280 temp
              W_postgres.prepared("insert_sensor_item")(2)(humidity / 1024.0).exec(); //bme280 hum
              W_postgres.prepared("insert_sensor_item")(5)(Si1132_readUV() / 100.0).exec(); //si1132 uv index
              W_postgres.prepared("insert_sensor_item")(6)(Si1132_readVisible()).exec(); //si1132 visible
              W_postgres.prepared("insert_sensor_item")(7)(Si1132_readIR()).exec(); //si1132 IR
              W_postgres.prepared("insert_sensor_item")(8)(pressure_mmhg).exec(); //bme280 pressure_mmhg
              W_postgres.commit();
              cout << "WeatherBoard records inserted successfully" << endl;
            }
          catch(const std::exception &e)
            {
              cout << "Error at inserting WeatherBoard to local postgreSQL database" << endl;
              cerr << e.what() << endl;
              return 1;
            }
          /* Инсертим 1-wire в базу*/
          if(g_devCnt > 0)
            {
              try
                {
                  /* Create a transactional object. */
                  work W_postgres(C_postgres);
                  while(1)
                    {
                      W_postgres.prepared("insert_sensor_item")(ds18dev_sensor_id[i])(ds18_sensor_temp[i]).exec(); //1-wire temperature insert
                      i++;
                      if(i == g_devCnt)
                        {
                          i = 0;
                          break;
                        }
                    }
                  W_postgres.commit();
                  cout << "1-wire records inserted successfully" << endl;
                }
              catch(const std::exception &e)
                {
                  cout << "Error at inserting 1-wire to local postgreSQL database" << endl;
                  cerr << e.what() << endl;
                  return 1;
                }
            }
        }
      //Отправляем значения в сервис Narodmon.ru
      if(l_count_current % g_count_for_send_narodmon == 0)
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
              //Добавляем передачу 1-wire на narodmon
              if(g_devCnt > 0)
                {
                  i = 0;
                  while(1)
                    {
                      l_buffer_for_double << (ds18_sensor_temp[i]);
                      l_send_payload = l_send_payload + "&DS" + to_string(ds18dev_sensor_id[i])  + "=" +  l_buffer_for_double.str();
                      l_buffer_for_double.str("");
                      l_buffer_for_double.clear();
                      i++;
                      if(i == g_devCnt)
                        {
                          i = 0;
                          break;
                        }
                    }
                }
              //
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
              // return 1; Отменяем выход, пусть локально работает и дальше - вдруг интернет умер
            }
        }
      if(l_count_current % g_count_for_cleanup_db == 0)
        {
          /* Чистим базу от старых данных*/
          try
            {
              /* Create a transactional object. */
              work W_postgres(C_postgres);
              cout << "Start DB cleanup" << endl;
              /* Execute prepared SQL query */
              W_postgres.prepared("cleanup_base").exec();
              W_postgres.commit();
              cout << "DB cleanup complete" << endl;
            }
          catch(const std::exception &e)
            {
              cout << "Error at DB cleanup" << endl;
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

# odroid_smarthome
Проект чтения датчиков i2c с локальным хранилищем и передачей на narodmon.ru
За основу взята плата Odroid-c1+ (http://www.hardkernel.com/main/products/prdt_info.php?g_code=G143703355573) и weather board 2 (http://www.hardkernel.com/main/products/prdt_info.php?g_code=G144533067183).
За основу взял исходники для работы с платой сенсоров из тестового примера и внес изменения для компиляции под С++.

Цель проекта - сделать на основе данной платы мониторинг температуры и света на улице на основе weatherboard2, температуры с россыпи датчиков по протоколу 1wire и  видеонаблюдение.
Первоначальный сбор показаний датчиков идет в локальную postgreSQL БД, с дальнейшей передачей в любой сервис.




Lunux
Для добавления программы в автозапуск надо скопировать файл \scripts\odroid_smarthome.conf в \etc\init\

Компиляция
make

Запуск 
sudo ./odroid_smarthome

Нужны пакеты
sudo apt-get update && sudo apt-get upgrade
sudo apt-get install libcurl4-openssl-dev

Нужно добавить модули ядра
echo "aml_i2c" | sudo tee -a /etc/modules
echo "w1-gpio" | sudo tee -a /etc/modules
echo "w1-therm" | sudo tee -a /etc/modules

PostgreSQL
Для создания таблиц в БД PostgreSQL надо выполнить скрипт \postgreSQL\create_db\smarthome.sql
Настройки postgreSQL лежат в \postgreSQL\config\

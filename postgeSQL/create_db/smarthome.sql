--PostgreSQL Maestro 15.4.0.2
------------------------------------------
--Host     : 192.168.5.34
--Database : smarthome


\connect - postgres
CREATE DATABASE smarthome WITH TEMPLATE = template0 ENCODING = 6 TABLESPACE = pg_default;
\connect smarthome postgres
-- Structure for table sensor_header (OID = 17029):
SET search_path = public, pg_catalog;
CREATE TABLE sensor_header (
    sensor_id integer NOT NULL,
    name varchar
) WITHOUT OIDS;
-- Structure for table sensor_items (OID = 17035):
CREATE TABLE sensor_items (
    sensor_id integer NOT NULL,
    value_number numeric(10,2),
    sysd timestamp without time zone DEFAULT date_trunc('second'::text, now()) NOT NULL
) WITHOUT OIDS;
-- Definition for index pk_sensor_header (OID = 17055):
ALTER TABLE ONLY sensor_header
    ADD CONSTRAINT pk_sensor_header PRIMARY KEY (sensor_id);
-- Definition for index fk_sensor_items_to_h (OID = 17057):
ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT fk_sensor_items_to_h FOREIGN KEY (sensor_id) REFERENCES sensor_header(sensor_id);
-- Definition for index pk_sensor_items (OID = 17065):
ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT pk_sensor_items PRIMARY KEY (sensor_id, sysd);
COMMENT ON SCHEMA public IS 'standard public schema';
--
-- Comments
--
COMMENT ON TABLE sensor_header IS 'Шапка для сенсоров';
COMMENT ON COLUMN sensor_header.sensor_id IS 'PK сенсора';
COMMENT ON COLUMN sensor_header.name IS 'Имя сенсора';
COMMENT ON TABLE sensor_items IS 'Строки датчиков';
COMMENT ON COLUMN sensor_items.sensor_id IS 'FK';
COMMENT ON COLUMN sensor_items.value_number IS 'Значение';
COMMENT ON COLUMN sensor_items.sysd IS 'Дата измерения';
COMMENT ON INDEX fk_sensor_items_to_h IS 'FK';

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.11
-- Dumped by pg_dump version 9.3.0
-- Started on 2016-04-03 11:50:49

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 2006 (class 1262 OID 17028)
-- Name: smarthome; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE smarthome WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE smarthome OWNER TO postgres;

\connect smarthome

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 2007 (class 1262 OID 17028)
-- Dependencies: 2006
-- Name: smarthome; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE smarthome IS 'База для утилиты odroid_smarthome';


--
-- TOC entry 179 (class 3079 OID 11788)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2010 (class 0 OID 0)
-- Dependencies: 179
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 192 (class 1255 OID 34928)
-- Name: f_get_ds18_sensor_id(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION f_get_ds18_sensor_id(p_ds18_serial character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
  l_sensor_id numeric;
BEGIN
  select sh.sensor_id into strict l_sensor_id from sensor_header sh where upper(sh.ds18_name)=upper(p_ds18_serial::varchar);
  return l_sensor_id;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  insert into sensor_header (sensor_id,ds18_name) values(default,p_ds18_serial::varchar) returning sensor_id into l_sensor_id;
  return  l_sensor_id;
END;
$$;


ALTER FUNCTION public.f_get_ds18_sensor_id(p_ds18_serial character varying) OWNER TO postgres;

--
-- TOC entry 193 (class 1255 OID 34496)
-- Name: p_cleanup(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION p_cleanup() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
l_cleanup_days numeric; --Сколько дней храним
l_round_days numeric; --После скольки усредняем
BEGIN
/*
sav 02.04.2016 
Удаляем все что старее 1000 дней
/ 
Округляем до средних за 5 минут показателй после 35 дней
 
 
 */
  select sc.attr_num 
 into l_cleanup_days 
  from smarthome_config sc 
  where  upper(sc.attr_name) = upper('g_cleanup_days');
  
   select sc.attr_num 
 into l_round_days 
  from smarthome_config sc 
  where  upper(sc.attr_name) = upper('g_round_days');
  
   
 insert into sensor_items_temp (sensor_id,sysd,value_number)
select q.sensor_id, 
(q.hour_stump + (min5_slot||' min')::interval) as sysd
,q.rnd_val as value_number   from 

(SELECT si.sensor_id,
date_trunc('hour', si.sysd) AS hour_stump
      ,(extract(minute FROM si.sysd)::int / 5)*5 AS min5_slot
      , round(avg(si.value_number),2) as rnd_val
FROM   sensor_items si 
where date_trunc('day',si.sysd) < (now() - (l_round_days||' day')::INTERVAL)
and si.record_type=1
GROUP  BY 1, 2,3
ORDER  BY 2, 3,1)
q
ORDER  BY 2,1
;
 delete 
from sensor_items si 
where si.sysd < (now() - (l_round_days||' day')::INTERVAL)
and si.record_type=1;
insert into sensor_items (record_type,sensor_id,sysd,value_number)
select 
2 as record_rype,
st.sensor_id,
st.sysd,
st.value_number 
from sensor_items_temp st 
where not exists (
 select 1 from sensor_items 
  si where 
  si.record_type=2 
  and si.sensor_id=st.sensor_id 
  and si.sysd=st.sysd 

  );
delete from sensor_items_temp;
/*
 delete 
from sensor_items si 
where si.sysd < (now() - (l_cleanup_days||' day')::INTERVAL);

*/
/*EXCEPTION
WHEN others THEN
  null; */
END;
$$;


ALTER FUNCTION public.p_cleanup() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 174 (class 1259 OID 17029)
-- Name: sensor_header; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_header (
    sensor_id integer DEFAULT nextval(('public.sensor_header_sensor_id_seq'::text)::regclass) NOT NULL,
    name character varying,
    ds18_name character varying(16)
);


ALTER TABLE public.sensor_header OWNER TO postgres;

--
-- TOC entry 2013 (class 0 OID 0)
-- Dependencies: 174
-- Name: TABLE sensor_header; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_header IS 'Шапка для сенсоров';


--
-- TOC entry 2014 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN sensor_header.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.sensor_id IS 'PK сенсора';


--
-- TOC entry 2015 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN sensor_header.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.name IS 'Имя сенсора для narodmon';


--
-- TOC entry 2016 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN sensor_header.ds18_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.ds18_name IS 'Серийный номер сенсора DS18B20';


--
-- TOC entry 178 (class 1259 OID 34897)
-- Name: sensor_header_sensor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sensor_header_sensor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE public.sensor_header_sensor_id_seq OWNER TO postgres;

--
-- TOC entry 177 (class 1259 OID 34529)
-- Name: sensor_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_items (
    sensor_id integer NOT NULL,
    record_type integer NOT NULL,
    sysd timestamp without time zone DEFAULT date_trunc('second'::text, now()) NOT NULL,
    value_number numeric(10,2)
);


ALTER TABLE public.sensor_items OWNER TO postgres;

--
-- TOC entry 2017 (class 0 OID 0)
-- Dependencies: 177
-- Name: TABLE sensor_items; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_items IS 'Строки датчиков';


--
-- TOC entry 2018 (class 0 OID 0)
-- Dependencies: 177
-- Name: COLUMN sensor_items.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.sensor_id IS 'FK';


--
-- TOC entry 2019 (class 0 OID 0)
-- Dependencies: 177
-- Name: COLUMN sensor_items.record_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.record_type IS 'Тип записи.
1=Для данных с датчиков
2=Для усреднения за 5 минут';


--
-- TOC entry 2020 (class 0 OID 0)
-- Dependencies: 177
-- Name: COLUMN sensor_items.sysd; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.sysd IS 'Дата измерения';


--
-- TOC entry 2021 (class 0 OID 0)
-- Dependencies: 177
-- Name: COLUMN sensor_items.value_number; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.value_number IS 'Значение';


--
-- TOC entry 176 (class 1259 OID 34497)
-- Name: sensor_items_temp; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_items_temp (
    sensor_id integer NOT NULL,
    value_number numeric(10,2),
    sysd timestamp without time zone DEFAULT date_trunc('second'::text, now()) NOT NULL
);


ALTER TABLE public.sensor_items_temp OWNER TO postgres;

--
-- TOC entry 2022 (class 0 OID 0)
-- Dependencies: 176
-- Name: TABLE sensor_items_temp; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_items_temp IS 'Временная таблица для усреднения значений';


--
-- TOC entry 2023 (class 0 OID 0)
-- Dependencies: 176
-- Name: COLUMN sensor_items_temp.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items_temp.sensor_id IS 'FK';


--
-- TOC entry 2024 (class 0 OID 0)
-- Dependencies: 176
-- Name: COLUMN sensor_items_temp.value_number; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items_temp.value_number IS 'Значение';


--
-- TOC entry 2025 (class 0 OID 0)
-- Dependencies: 176
-- Name: COLUMN sensor_items_temp.sysd; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items_temp.sysd IS 'Дата измерения';


--
-- TOC entry 175 (class 1259 OID 34141)
-- Name: smarthome_config; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE smarthome_config (
    attr_name character varying NOT NULL,
    attr_description character varying NOT NULL,
    attr_num numeric,
    attr_char character varying,
    CONSTRAINT smarthome_config_chk CHECK (((attr_num IS NOT NULL) OR (attr_char IS NOT NULL)))
);


ALTER TABLE public.smarthome_config OWNER TO postgres;

--
-- TOC entry 2026 (class 0 OID 0)
-- Dependencies: 175
-- Name: TABLE smarthome_config; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE smarthome_config IS 'Глобальный конфиг платы';


--
-- TOC entry 2027 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_name IS 'Имя параметра';


--
-- TOC entry 2028 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_description; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_description IS 'Описание параметра';


--
-- TOC entry 2029 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_num; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_num IS 'Числовое значение';


--
-- TOC entry 2030 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_char; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_char IS 'Значание символы';


--
-- TOC entry 1888 (class 2606 OID 34148)
-- Name: PK_smarthome_config; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY smarthome_config
    ADD CONSTRAINT "PK_smarthome_config" PRIMARY KEY (attr_name);


--
-- TOC entry 1885 (class 2606 OID 34900)
-- Name: pk_sensor_header; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_header
    ADD CONSTRAINT pk_sensor_header PRIMARY KEY (sensor_id);


--
-- TOC entry 1892 (class 2606 OID 34543)
-- Name: pk_sensor_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT pk_sensor_items PRIMARY KEY (record_type, sensor_id, sysd) WITH (fillfactor=100);


--
-- TOC entry 1890 (class 2606 OID 34502)
-- Name: sensor_items_temp_pk_sensor_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_items_temp
    ADD CONSTRAINT sensor_items_temp_pk_sensor_items PRIMARY KEY (sensor_id, sysd) WITH (fillfactor=100);


--
-- TOC entry 1886 (class 1259 OID 34919)
-- Name: sensor_header_idx_ds18_uname; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sensor_header_idx_ds18_uname ON sensor_header USING btree (upper((ds18_name)::text));


--
-- TOC entry 1893 (class 1259 OID 34896)
-- Name: sensor_items_idx1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sensor_items_idx1 ON sensor_items USING btree (sensor_id, sysd);


--
-- TOC entry 1894 (class 2606 OID 34901)
-- Name: fk_sensor_items_to_h; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT fk_sensor_items_to_h FOREIGN KEY (sensor_id) REFERENCES sensor_header(sensor_id);


--
-- TOC entry 2009 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- TOC entry 2011 (class 0 OID 0)
-- Dependencies: 192
-- Name: f_get_ds18_sensor_id(character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION f_get_ds18_sensor_id(p_ds18_serial character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION f_get_ds18_sensor_id(p_ds18_serial character varying) FROM postgres;
GRANT ALL ON FUNCTION f_get_ds18_sensor_id(p_ds18_serial character varying) TO postgres;
GRANT ALL ON FUNCTION f_get_ds18_sensor_id(p_ds18_serial character varying) TO PUBLIC;


--
-- TOC entry 2012 (class 0 OID 0)
-- Dependencies: 193
-- Name: p_cleanup(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION p_cleanup() FROM PUBLIC;
REVOKE ALL ON FUNCTION p_cleanup() FROM postgres;
GRANT ALL ON FUNCTION p_cleanup() TO postgres;
GRANT ALL ON FUNCTION p_cleanup() TO PUBLIC;


-- Completed on 2016-04-03 11:50:51

--
-- PostgreSQL database dump complete
--


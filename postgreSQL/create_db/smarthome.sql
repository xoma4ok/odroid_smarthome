--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.11
-- Dumped by pg_dump version 9.3.0
-- Started on 2016-04-02 22:08:03

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 2004 (class 1262 OID 17028)
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
-- TOC entry 179 (class 3079 OID 11788)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2007 (class 0 OID 0)
-- Dependencies: 179
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 192 (class 1255 OID 34496)
-- Name: P_CLEANUP(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "P_CLEANUP"() RETURNS void
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


ALTER FUNCTION public."P_CLEANUP"() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 174 (class 1259 OID 17029)
-- Name: sensor_header; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_header (
    sensor_id integer NOT NULL,
    name character varying
);


ALTER TABLE public.sensor_header OWNER TO postgres;

--
-- TOC entry 2008 (class 0 OID 0)
-- Dependencies: 174
-- Name: TABLE sensor_header; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_header IS 'Шапка для сенсоров';


--
-- TOC entry 2009 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN sensor_header.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.sensor_id IS 'PK сенсора';


--
-- TOC entry 2010 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN sensor_header.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.name IS 'Имя сенсора для narodmon';


--
-- TOC entry 178 (class 1259 OID 34529)
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
-- TOC entry 2011 (class 0 OID 0)
-- Dependencies: 178
-- Name: TABLE sensor_items; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_items IS 'Строки датчиков';


--
-- TOC entry 2012 (class 0 OID 0)
-- Dependencies: 178
-- Name: COLUMN sensor_items.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.sensor_id IS 'FK';


--
-- TOC entry 2013 (class 0 OID 0)
-- Dependencies: 178
-- Name: COLUMN sensor_items.record_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.record_type IS 'Тип записи.
1=Для данных с датчиков
2=Для усреднения за 5 минут';


--
-- TOC entry 2014 (class 0 OID 0)
-- Dependencies: 178
-- Name: COLUMN sensor_items.sysd; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.sysd IS 'Дата измерения';


--
-- TOC entry 2015 (class 0 OID 0)
-- Dependencies: 178
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
-- TOC entry 2016 (class 0 OID 0)
-- Dependencies: 176
-- Name: TABLE sensor_items_temp; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_items_temp IS 'Временная таблица для усреднения значений';


--
-- TOC entry 2017 (class 0 OID 0)
-- Dependencies: 176
-- Name: COLUMN sensor_items_temp.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items_temp.sensor_id IS 'FK';


--
-- TOC entry 2018 (class 0 OID 0)
-- Dependencies: 176
-- Name: COLUMN sensor_items_temp.value_number; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items_temp.value_number IS 'Значение';


--
-- TOC entry 2019 (class 0 OID 0)
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
-- TOC entry 2020 (class 0 OID 0)
-- Dependencies: 175
-- Name: TABLE smarthome_config; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE smarthome_config IS 'Глобальный конфиг платы';


--
-- TOC entry 2021 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_name IS 'Имя параметра';


--
-- TOC entry 2022 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_description; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_description IS 'Описание параметра';


--
-- TOC entry 2023 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_num; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_num IS 'Числовое значение';


--
-- TOC entry 2024 (class 0 OID 0)
-- Dependencies: 175
-- Name: COLUMN smarthome_config.attr_char; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_char IS 'Значание символы';


--
-- TOC entry 1886 (class 2606 OID 34148)
-- Name: PK_smarthome_config; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY smarthome_config
    ADD CONSTRAINT "PK_smarthome_config" PRIMARY KEY (attr_name);


--
-- TOC entry 1884 (class 2606 OID 17056)
-- Name: pk_sensor_header; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_header
    ADD CONSTRAINT pk_sensor_header PRIMARY KEY (sensor_id);


--
-- TOC entry 1890 (class 2606 OID 34543)
-- Name: pk_sensor_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT pk_sensor_items PRIMARY KEY (record_type, sensor_id, sysd) WITH (fillfactor=100);


--
-- TOC entry 1888 (class 2606 OID 34502)
-- Name: sensor_items_temp_pk_sensor_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_items_temp
    ADD CONSTRAINT sensor_items_temp_pk_sensor_items PRIMARY KEY (sensor_id, sysd) WITH (fillfactor=100);


--
-- TOC entry 1891 (class 1259 OID 34896)
-- Name: sensor_items_idx1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sensor_items_idx1 ON sensor_items USING btree (sensor_id, sysd);


--
-- TOC entry 1892 (class 2606 OID 34535)
-- Name: fk_sensor_items_to_h; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT fk_sensor_items_to_h FOREIGN KEY (sensor_id) REFERENCES sensor_header(sensor_id);


--
-- TOC entry 2025 (class 0 OID 0)
-- Dependencies: 1892
-- Name: CONSTRAINT fk_sensor_items_to_h ON sensor_items; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON CONSTRAINT fk_sensor_items_to_h ON sensor_items IS 'FK';


--
-- TOC entry 2006 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2016-04-02 22:08:16

--
-- PostgreSQL database dump complete
--


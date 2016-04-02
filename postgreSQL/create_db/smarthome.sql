--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.11
-- Dumped by pg_dump version 9.3.0
-- Started on 2016-04-02 15:11:49

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 1991 (class 1262 OID 17028)
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
-- TOC entry 175 (class 3079 OID 11788)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 1994 (class 0 OID 0)
-- Dependencies: 175
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 172 (class 1259 OID 17029)
-- Name: sensor_header; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_header (
    sensor_id integer NOT NULL,
    name character varying
);


ALTER TABLE public.sensor_header OWNER TO postgres;

--
-- TOC entry 1995 (class 0 OID 0)
-- Dependencies: 172
-- Name: TABLE sensor_header; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_header IS 'Шапка для сенсоров';


--
-- TOC entry 1996 (class 0 OID 0)
-- Dependencies: 172
-- Name: COLUMN sensor_header.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.sensor_id IS 'PK сенсора';


--
-- TOC entry 1997 (class 0 OID 0)
-- Dependencies: 172
-- Name: COLUMN sensor_header.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_header.name IS 'Имя сенсора';


--
-- TOC entry 173 (class 1259 OID 17035)
-- Name: sensor_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_items (
    sensor_id integer NOT NULL,
    value_number numeric(10,2),
    sysd timestamp without time zone DEFAULT date_trunc('second'::text, now()) NOT NULL
);


ALTER TABLE public.sensor_items OWNER TO postgres;

--
-- TOC entry 1998 (class 0 OID 0)
-- Dependencies: 173
-- Name: TABLE sensor_items; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE sensor_items IS 'Строки датчиков';


--
-- TOC entry 1999 (class 0 OID 0)
-- Dependencies: 173
-- Name: COLUMN sensor_items.sensor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.sensor_id IS 'FK';


--
-- TOC entry 2000 (class 0 OID 0)
-- Dependencies: 173
-- Name: COLUMN sensor_items.value_number; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.value_number IS 'Значение';


--
-- TOC entry 2001 (class 0 OID 0)
-- Dependencies: 173
-- Name: COLUMN sensor_items.sysd; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN sensor_items.sysd IS 'Дата измерения';


--
-- TOC entry 174 (class 1259 OID 34141)
-- Name: smarthome_config; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE smarthome_config (
    attr_name character varying NOT NULL,
    attr_description character varying NOT NULL,
    attr_num numeric,
    attr_char character varying
);


ALTER TABLE public.smarthome_config OWNER TO postgres;

--
-- TOC entry 2002 (class 0 OID 0)
-- Dependencies: 174
-- Name: TABLE smarthome_config; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE smarthome_config IS 'Глобальный конфиг платы';


--
-- TOC entry 2003 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN smarthome_config.attr_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_name IS 'Имя параметра';


--
-- TOC entry 2004 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN smarthome_config.attr_description; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_description IS 'Описание параметра';


--
-- TOC entry 2005 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN smarthome_config.attr_num; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_num IS 'Числовое значение';


--
-- TOC entry 2006 (class 0 OID 0)
-- Dependencies: 174
-- Name: COLUMN smarthome_config.attr_char; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN smarthome_config.attr_char IS 'Значание символы';


--
-- TOC entry 1878 (class 2606 OID 34148)
-- Name: PK_smarthome_config; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY smarthome_config
    ADD CONSTRAINT "PK_smarthome_config" PRIMARY KEY (attr_name);


--
-- TOC entry 1873 (class 2606 OID 17056)
-- Name: pk_sensor_header; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_header
    ADD CONSTRAINT pk_sensor_header PRIMARY KEY (sensor_id);


--
-- TOC entry 1876 (class 2606 OID 17066)
-- Name: pk_sensor_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT pk_sensor_items PRIMARY KEY (sensor_id, sysd) WITH (fillfactor=100);


--
-- TOC entry 1871 (class 1259 OID 25282)
-- Name: I_sensor_header_1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX "I_sensor_header_1" ON sensor_header USING btree (sensor_id);


--
-- TOC entry 1874 (class 1259 OID 25283)
-- Name: I_sensor_items_id_date; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX "I_sensor_items_id_date" ON sensor_items USING btree (sensor_id, sysd) WITH (fillfactor='100');


--
-- TOC entry 1879 (class 2606 OID 17057)
-- Name: fk_sensor_items_to_h; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sensor_items
    ADD CONSTRAINT fk_sensor_items_to_h FOREIGN KEY (sensor_id) REFERENCES sensor_header(sensor_id);


--
-- TOC entry 2007 (class 0 OID 0)
-- Dependencies: 1879
-- Name: CONSTRAINT fk_sensor_items_to_h ON sensor_items; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON CONSTRAINT fk_sensor_items_to_h ON sensor_items IS 'FK';


--
-- TOC entry 1993 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2016-04-02 15:11:50

--
-- PostgreSQL database dump complete
--


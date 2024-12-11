-- =========================================== BANCO ============================================================
CREATE DATABASE biosentinel_database;
USE biosentinel_database;

-- =========================================== TABELAS ============================================================
-- Criação da tabela `animal`
CREATE TABLE animal (
    id_animal INT AUTO_INCREMENT PRIMARY KEY,
    species VARCHAR(45) NOT NULL,
    habitat VARCHAR(45) NOT NULL,
    identifier VARCHAR(45) NOT NULL
);

-- Inserção de dados na tabela `animal`
INSERT INTO animal (species, habitat, identifier) 
VALUES ('Panthera onca', 'Forests', 'Jaguar');

-- Seleção de todos os dados da tabela `animal`
SELECT * FROM animal;

-- Criação da tabela `sensor`
CREATE TABLE sensor (
    id_sensor INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(45) NOT NULL,
    type VARCHAR(45) NOT NULL,
    description VARCHAR(45)
);

-- Inserção de dados na tabela `sensor`
INSERT INTO sensor (name, type) VALUES 
 ('ECG AD8232', 'Heart Rate'),
 ('ECG AD8232', 'Electric Pulse'),
 ('Amped', 'Heart Rate'),
 ('Amped', 'Blood Pressure'),
 ('GPS GY-NEO6MV2', 'Geolocation'),
 ('DS18B20', 'Animal Temperature'),
 ('DHT-22', 'Environment Temperature'),
 ('osoyoo', 'Sound'),
 ('HC-SR04', 'Presence'),
 ('DHT-22', 'Humidity');

-- Seleção de todos os dados da tabela `sensor`
SELECT * FROM sensor;

-- Criação da tabela `animal_sensor`
CREATE TABLE animal_sensor (
    fk_animal INT NOT NULL,
    fk_sensor INT NOT NULL,
    min DECIMAL(10, 2) NOT NULL,
    max DECIMAL(10, 2) NOT NULL,
    offset DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (fk_animal, fk_sensor),
    FOREIGN KEY (fk_animal) REFERENCES animal(id_animal),
    FOREIGN KEY (fk_sensor) REFERENCES sensor(id_sensor)
);

-- Inserção de dados na tabela `animal_sensor`
INSERT INTO animal_sensor (fk_animal, fk_sensor, min, max, offset) VALUES
(1, 1, 50.0, 120.0, 10.0),
(1, 2, 0.5, 5.0, 2.25);

-- Seleção de todos os dados da tabela `animal_sensor`
SELECT * FROM animal_sensor;

-- Criação da tabela `data_sensor`
CREATE TABLE data_sensor (
    id_data INT AUTO_INCREMENT PRIMARY KEY,
    created_at DATETIME NOT NULL,
    value VARCHAR(45) NOT NULL,
    fk_sensor INT NOT NULL,
    FOREIGN KEY (fk_sensor) REFERENCES sensor(id_sensor),
    measurement VARCHAR(45) NOT NULL
);

-- Inserção de dados na tabela `data_sensor`
INSERT INTO data_sensor (created_at, value, fk_sensor, measurement) VALUES
('2024-05-30', '83', 1, 'bpm');

-- Seleção de todos os dados da tabela `data_sensor`, convertendo o formato de data
SELECT id_data,
       DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as created_at,
       value,
       fk_sensor,
       measurement
FROM data_sensor;

-- =========================================== VIEWS ============================================================
-- GEOLOCALIZAÇÃO
CREATE OR REPLACE VIEW vw_parser_geolocation AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.lat') AS DECIMAL(10, 6)) AS lat,
    CAST(JSON_EXTRACT(value, '$.value.lon') AS DECIMAL(10, 6)) AS lon,
    JSON_EXTRACT(value, '$.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 3;

-- FREQUÊNCIA CARDÍACA
CREATE OR REPLACE VIEW vw_parser_heart_rate AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.heart_rate.value') AS DECIMAL(10, 2)) AS heart_rate,
    JSON_EXTRACT(value, '$.value.heart_rate.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 2;

-- PULSO ELÉTRICO
CREATE OR REPLACE VIEW vw_parser_electric_pulse AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.electric_pulse.value') AS DECIMAL(10, 2)) AS electric_pulse,
    JSON_EXTRACT(value, '$.value.electric_pulse.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 2;

-- UMIDADE
CREATE OR REPLACE VIEW vw_parser_humidity AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.humid.value') AS DECIMAL(10, 2)) AS humidity,
    JSON_EXTRACT(value, '$.value.humid.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 5;

-- TEMPERATURA
CREATE OR REPLACE VIEW vw_parser_temperature AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.temperature.value') AS DECIMAL(10, 2)) AS temperature,
    JSON_EXTRACT(value, '$.value.temperature.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 5;

-- SOM
CREATE OR REPLACE VIEW vw_parser_sound AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.sound.value') AS DECIMAL(10, 2)) AS sound,
    JSON_EXTRACT(value, '$.value.sound.measurement') AS measurement,
    JSON_EXTRACT(value, '$.value.description.value') AS description,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 4;

-- TEMPERATURA DO ANIMAL
CREATE OR REPLACE VIEW vw_parser_animal_temperature AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.temp.value') AS DECIMAL(10, 2)) AS temperature,
    JSON_EXTRACT(value, '$.value.temp.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 6;

-- PRESSÃO SANGUÍNEA
CREATE OR REPLACE VIEW vw_parser_animal_pressure AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value.pressure.value') AS DECIMAL(10, 2)) AS pressure,
    JSON_EXTRACT(value, '$.value.pressure.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 6;

-- PRESENÇA
CREATE OR REPLACE VIEW vw_parser_presence AS
SELECT 
    fk_sensor,
    CAST(JSON_EXTRACT(value, '$.value') AS DECIMAL(10, 2)) AS presence,
    JSON_EXTRACT(value, '$.measurement') AS measurement,
    STR_TO_DATE(CONCAT(
        SUBSTRING(created_at, 1, 10), ' ',
        REPLACE(SUBSTRING(created_at, 12, 8), '-', ':')
    ), '%Y-%m-%d %H:%i:%s') AS created_at
FROM data_sensor
WHERE fk_sensor = 1;

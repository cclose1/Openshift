DROP VIEW IF EXISTS Spend;

DROP TABLE IF EXISTS SpendData;

CREATE TABLE SpendData (
  SeqNo       int(11)       NOT NULL AUTO_INCREMENT,
  Modified    Datetime      DEFAULT NULL, 
  IncurredBy  VARCHAR(20)   DEFAULT 'Chris',
  Timestamp   datetime      DEFAULT NULL,
  Category    varchar(20)   DEFAULT NULL,
  Type        varchar(20)   DEFAULT NULL,
  Description varchar(1000) DEFAULT NULL,
  Location    varchar(1000) DEFAULT NULL,
  Amount      decimal(10,2) DEFAULT NULL,
  Monthly     char(1)       DEFAULT NULL,
  `Ignore`    char(1)       DEFAULT NULL,
  Period      char(1)       DEFAULT NULL,
  PRIMARY KEY (SeqNo)
);

CREATE VIEW Spend AS 
SELECT 
	SeqNo,
	Modified,
	IncurredBy,
	Timestamp,
	CAST(Timestamp AS Date)        AS Date,
	CAST(Timestamp AS Time)        AS Time,
	Year(Timestamp)                AS Year,
	Month(Timestamp)               AS Month,
	DayOfMonth(Timestamp)          AS Day,
	Week(Timestamp,0)              AS Week,
	SUBSTR(DAYNAME(Timestamp),1,3) AS Weekday,
	CASE
		WHEN DAYOFWEEK(Timestamp) = 2 THEN DAYOFYEAR(Timestamp)
		WHEN DAYOFWEEK(Timestamp) = 3 THEN DAYOFYEAR(DATE_ADD(Timestamp, INTERVAL -1 DAY))
		WHEN DAYOFWEEK(Timestamp) = 4 THEN DAYOFYEAR(DATE_ADD(Timestamp, INTERVAL -2 DAY))
		WHEN DAYOFWEEK(Timestamp) = 5 THEN DAYOFYEAR(DATE_ADD(Timestamp, INTERVAL -3 DAY))
		WHEN DAYOFWEEK(Timestamp) = 6 THEN DAYOFYEAR(DATE_ADD(Timestamp, INTERVAL -4 DAY))
		WHEN DAYOFWEEK(Timestamp) = 7 THEN DAYOFYEAR(DATE_ADD(Timestamp, INTERVAL -5 DAY))
		WHEN DAYOFWEEK(Timestamp) = 1 THEN DAYOFYEAR(DATE_ADD(Timestamp, INTERVAL -6 DAY))
		ELSE -1
	END FirstWeekday,
	Category,
	Type,
	Amount,
	Description,
	Location,
	Period,
	`Ignore`
from SpendData;


DELIMITER //

CREATE TRIGGER InsSpendData BEFORE INSERT ON SpendData
FOR EACH ROW
BEGIN
	SET NEW.Modified = COALESCE(NEW.Modified, NOW());
END;//

CREATE TRIGGER UpdSpendData BEFORE UPDATE ON SpendData
FOR EACH ROW
BEGIN
	IF NEW.Modified = OLD.Modified THEN
		SET NEW.Modified = NOW();
	END IF;
END;//

DELIMITER ;
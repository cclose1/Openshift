CREATE TABLE SpendData (
  SeqNo       int(11)       NOT NULL AUTO_INCREMENT,
  Timestamp   datetime      DEFAULT NULL,
  Category    varchar(20)   DEFAULT NULL,
  Type        varchar(20)   DEFAULT NULL,
  Description varchar(1000) DEFAULT NULL,
  Location    varchar(1000) DEFAULT NULL,
  Amount      decimal(10,2) DEFAULT NULL,
  Monthly     char(1)       DEFAULT NULL,
  `Ignore`    char(1)       DEFAULT NULL,
  PRIMARY KEY (SeqNo)
);
CREATE VIEW Spend AS 
SELECT 
	SeqNo,
	Timestamp,
	CAST(Timestamp AS DATE)          AS Date,
	CAST(Timestamp AS TIME)          AS Time,
	year(Timestamp)                  AS Year,
	month(Timestamp)                 AS Month,
	dayofmonth(Timestamp)            AS Day,
	week(Timestamp, 0)               AS Week,
	substr(dayname(Timestamp), 1, 3) AS Weekday,
	Category,
	Type,
	Amount,
	Description,
	Location,
	Monthly,
	`Ignore`
FROM SpendData;

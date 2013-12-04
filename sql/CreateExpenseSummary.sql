USE Expenditure;

DROP PROCEDURE IF EXISTS Summary;

DELIMITER //

CREATE PROCEDURE Summary(start DATETIME, adjustDay INT, adjustAmount DECIMAL(10, 2))
BEGIN
	DECLARE lMonth    INT;
	DECLARE mSpend    DECIMAL(10, 2);
	DECLARE target    DECIMAL(10, 2);
	DECLARE maxDate   DATETIME;
	DECLARE done      INT            DEFAULT FALSE;
	DECLARE mFixed    DECIMAL(10, 2) DEFAULT 0;
	DECLARE mMonth    DECIMAL(10, 2) DEFAULT 0;
	DECLARE tDay      INT            DEFAULT 0;
	DECLARE monthDays INT            DEFAULT 0;
	DECLARE yFixed    DECIMAL(10, 2);
	DECLARE yHoliday  DECIMAL(10, 2);

	DECLARE cSpend CURSOR 
	FOR 
	SELECT 
		Year,
		Month,
		Category,
		Max(Timestamp) AS Latest,
		Sum(Amount)    AS Amount		
	FROM Spend 
	WHERE (start IS NULL OR Timestamp >= start)
	AND   Timestamp                   < maxDate
	AND   COALESCE(`Ignore`, 'N')     = 'N'
	GROUP BY Year, Month, Category
	ORDER BY Year, Month, Category;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
	DROP TEMPORARY TABLE IF EXISTS Expenditure.Details;

	CREATE TEMPORARY TABLE Expenditure.Details(
				Year          INT,
				Month         INT,
				Days          INT,
				DailyRate     DECIMAL(10, 2),
				Necessary     DECIMAL(10, 2) DEFAULT 0,
				Fixed         DECIMAL(10, 2) DEFAULT 0,
				Essential     DECIMAL(10, 2) DEFAULT 0,
				Discretionary DECIMAL(10, 2) DEFAULT 0,
				Children      DECIMAL(10, 2) DEFAULT 0,
				Holiday       DECIMAL(10, 2) DEFAULT 0,
				Other         DECIMAL(10, 2) DEFAULT 0,
				YearFixed     DECIMAL(10, 2) DEFAULT 0,
				YearHoliday   DECIMAL(10, 2) DEFAULT 0,
				YearNecessary DECIMAL(10, 2) DEFAULT 0,
				YearEstimate  DECIMAL(10, 2) DEFAULT 0,
				MonthSpend    DECIMAL(10, 2) DEFAULT 0,
				Target        DECIMAL(10, 2) DEFAULT 0,
				UnderSpend    DECIMAL(10, 2) DEFAULT 0,
				PRIMARY KEY (Year, Month));
	SET target  = 20000;
	SET maxDate = ADDDATE(CURDATE(), INTERVAL 1 DAY);
	SET lMonth = 0;

	IF start IS NULL THEN 
		SET start = (SELECT MIN(Timestamp) FROM SpendData WHERE Category = 'Essential');
	END IF;

	OPEN cSpend;

readSpend: 
	LOOP
	BEGIN
		DECLARE cYear      VARCHAR(100);
		DECLARE cMonth     VARCHAR(5);
		DECLARE cCategory  VARCHAR(20);
		DECLARE cLatest    DATETIME;
		DECLARE cAmount    DECIMAL(10, 2);
		DECLARE yNecessary DECIMAL(10, 2);

		FETCH NEXT FROM cSpend INTO cYear, cMonth, cCategory, cLatest, cAmount;

		IF done THEN
			LEAVE readSpend;
		END IF;

		IF lMonth IS NULL OR lMonth <> cMonth THEN
			SET cLatest = NULL;
			SET cLatest = (
				SELECT 
					MAX(Timestamp)
				FROM Spend 
				WHERE Year                    = cYear
				AND   Month                   = cMonth
				AND   Category               <> 'Fixed'
				AND   Timestamp               < maxDate
				AND   COALESCE(`Ignore`, 'N') = 'N');
			SET monthDays = DAY(LAST_DAY(cLatest));
			SET tDay      = DAY(cLatest);

			SET yFixed = (
				SELECT
					COALESCE(SUM(Amount), 0)
				FROM Spend
				WHERE Timestamp BETWEEN ADDDATE(cLatest, INTERVAL -365 DAY) AND cLatest
				AND   Category                = 'Fixed'
				AND   COALESCE(`Ignore`, 'N') = 'N');

			SET yHoliday = (
				SELECT
					COALESCE(SUM(Amount), 0)
				FROM Spend
				WHERE Timestamp BETWEEN ADDDATE(cLatest, INTERVAL -365 DAY) AND cLatest
				AND   Category                = 'Holiday'
				AND   COALESCE(`Ignore`, 'N') = 'N');
			SET yNecessary = (
				SELECT
					COALESCE(SUM(Amount), 0)
				FROM Spend
				WHERE Timestamp BETWEEN ADDDATE(cLatest, INTERVAL -365 DAY) AND cLatest
				AND   Category                = 'Necessary'
				AND   COALESCE(`Ignore`, 'N') = 'N');
			/*
			 * Monthly amounts of type Discretionary and Essential, should be excluded from the monthly
			 * rate calculation.
			 *
			 * Set @mFixed to the last years contribution from these values and @mMonth to this months contibution
			 * from these values.
			 *
			 * These are required to calculate the yearly expenditure estimate.
			 */
			SET mFixed = 0;
			SET mMonth = 0;
			SET	mFixed = (
				SELECT COALESCE(SUM(Amount), 0)
				FROM Spend
				WHERE Timestamp BETWEEN ADDDATE(cLatest, INTERVAL -365 DAY) AND cLatest
				AND   Category           IN ('Discretionary', 'Essential')
				AND   Monthly             = 'Y'
				AND   COALESCE(`Ignore`, 'N') = 'N');

			SET mMonth = (
				SELECT
					COALESCE(SUM(Amount), 0)
				FROM Spend
				WHERE Timestamp BETWEEN ADDDATE(cLatest, INTERVAL -365 DAY) AND cLatest
				AND   Category           IN ('Discretionary', 'Essential')
				AND   Monthly             = 'Y'
				AND   Year                = cYear
				AND   Month               = cMonth
				AND   COALESCE(`Ignore`, 'N') = 'N');

			IF adjustDay IS NOT NULL THEN 
				SET tDay =  tDay + CASE WHEN adjustDay > monthDays THEN monthDays ELSE adjustDay END;
			END IF;

			IF tDay > monthDays THEN    
				SET tDay  = monthDays;
			END IF;
			
			INSERT Details(Year,  Month,  Days, YearFixed, YearHoliday, YearNecessary) 
			VALUES        (cYear, cMonth, tDay, yFixed,    yHoliday,    yNecessary);
			
			SET lMonth = cMonth;
			SET mSpend = 0;
		END IF;

		IF cCategory = 'Children' THEN
			UPDATE Details 
				SET Children   = cAmount,
					MonthSpend = MonthSpend + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		ELSEIF cCategory = 'Necessary' THEN
			UPDATE Details 
				SET Necessary  = cAmount,
					MonthSpend = MonthSpend + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		ELSEIF cCategory = 'Fixed' THEN
			UPDATE Details 
				SET Fixed      = cAmount,
					MonthSpend = MonthSpend + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		ELSEIF cCategory = 'Holiday' THEN
			UPDATE Details 
				SET Holiday   = cAmount,
					MonthSpend = MonthSpend + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		ELSEIF cCategory = 'Essential' THEN
			UPDATE Details 
				SET Essential  = cAmount,
					MonthSpend = MonthSpend + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		ELSEIF cCategory = 'Discretionary' THEN
			UPDATE Details 
				SET Discretionary = cAmount,
					MonthSpend    = MonthSpend + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		ELSE 
			UPDATE Details 
				SET Other      = Other + cAmount
			WHERE Year  = cYear
			AND   Month = cMonth;
		END IF;

		IF cCategory IN ('Essential', 'Discretionary') THEN
		BEGIN
			DECLARE rate DECIMAL(10, 2);
						
			SET mSpend = mSpend + cAmount;
			SET rate   = (mSpend - mMonth + COALESCE(adjustAmount, 0)) / tDay;

			UPDATE Details 
				SET Target       = target,
					DailyRate    = rate,
					YearEstimate = 12 * monthDays * rate + yFixed + yHoliday + mFixed,
					UnderSpend   = tDay * ((target - yFixed - yHoliday - mFixed) / 12 / monthDays - rate)
			WHERE Year  = cYear
			AND   Month = cMonth;
		END;
		END IF;
	END; 
	END LOOP;

	CLOSE cSpend;
	SELECT * FROM Details;
END;
//

DELIMITER ;

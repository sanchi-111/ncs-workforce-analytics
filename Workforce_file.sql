
---Project : National Career Service (NCS) WorkForce Analytics
-- Author: Sanchi Gupta
-- PHASE 1: Core Schema Setup

CREATE TABLE employers (
    id int primary key,
    month varchar(20),
    year_2023 int,
    year_2024 int,
    year_2025 int,
    total int
);

CREATE TABLE jobseekers (
    id int primary key,
    month varchar(20),
    year_2023 int,
    year_2024 int,
    year_2025 int,
    total int
);

/*  PHASE 2: Data Ingestion

  NOTE: Regular COPY command failed with Windows Permission Denied error 
  due to postgres local system account restrictions on C:/ drive.
  FIXED by using pgAdmin Import GUI tool,so the datasets were ingested using the pgAdmin 
  Ingestion tool under user session privileges. 
  DIRECTORY PATH: C:\Workforce_data\
  FILES: Employers_dataset.csv | Jobseekers_dataset.csv
  
1. Right-click on table -> Select 'Import/Export Data'
2. Switch mode to 'Import' and specify the local CSV path.
3. Enable 'Header: Yes' and define 'Delimiter: ,' within the Options layer. */


-- PHASE 3: Virtual Transformation & Market Math View
	
	CREATE OR REPLACE VIEW workforce_data AS 
	 WITH unpivoted_employers AS (
	 SELECT id, month,'2023' AS record_year, year_2023 AS employers_count FROM employers
	 UNION ALL 
	 SELECT id, month, '2024' AS record_year, year_2024 AS employers_count FROM employers
	 UNION ALL 
	 SELECT id, month, '2025' AS record_year, year_2025 AS employers_count FROM employers
	 ),
     unpivoted_jobseekers AS (
     SELECT id, month, '2023' AS record_year, year_2023 AS jobseekers_count FROM jobseekers
	 UNION ALL
	 SELECT id, month, '2024' AS record_year, year_2024 AS  jobseekers_count FROM jobseekers
	 UNION ALL 
	 SELECT id, month, '2025' AS record_year, year_2025 AS jobseekers_count FROM jobseekers
	 )

     SELECT e.id AS month_order_id,
     e.month,
     e.record_year,
     e.employers_count AS employer_demand,
     j.jobseekers_count AS jobseekers_supply,
     

--- Calculations-time
--- Now calculating Pure Supply-Demand Volume gap,and
--- analyzing do we have physical shortage of workers?

    (j.jobseekers_count - e.employers_count) AS supply_demand_gap,

/* Candidates per individual posting
   NULLIF would prevent "division by zero" errors if employee counts ever hit 0 */
   

ROUND(j.jobseekers_count:: Numeric / NULLIF(e.employers_count,0),2) AS competition_ratio,

-- Operational status logic gate

 CASE 
 WHEN (j.jobseekers_count:: Numeric / NULLIF(e.employers_count,0)) > 100 
 THEN 'SEVERE Talent Surplus'
 WHEN (j.jobseekers_count:: Numeric / NULLIF(e.employers_count,0)) < 10
 THEN 'SEVERE Talent Deficit'
 ELSE 'BALANCED Market Operations'
 END AS Operational_Status

 FROM unpivoted_employers e
 JOIN unpivoted_jobseekers j 
 ON e.id = j.id 
 AND e.record_year = j.record_year
 ORDER BY e.record_year,
 e.id

---Verification
  SELECT * FROM workforce_data

/*Step 4- Business Queries

-- Ques-1 Which specific months see the highesst candidate 
-- Business Purpose: Spot hiring spikes early so recruiters don't get overwhelmed.
-- Finding: Peak application periods create high competition ratios per vacancy.
-- Recommendation: Deploy automated screening filters during high-volume months. */

 SELECT 
     month,
	 record_year,
	 employer_demand,
	 jobseekers_supply,
	 competition_ratio
 FROM workforce_data 
 WHERE operational_status = 'SEVERE Talent Surplus -'
 ORDER BY competition_ratio DESC;

--------------------------------------------------------------------------------------------

--Q-2- In which periods do we face severe talent shortages ?
-- Business Purpose: Find when talent shortages happen so we don't miss client hiring deadlines.
-- Finding: When applicant numbers drop, it becomes hard to fill open positions on time.
-- Recommendation: Increase candidate recruiting efforts before busy hiring periods begin.

 SELECT 
     month,
	 record_year,
	 employer_demand,
	 jobseekers_supply,
	  supply_demand_gap, 
	 operational_status
 FROM workforce_data 
 WHERE operational_status = 'SEVERE Talent Deficit'
 ORDER BY supply_demand_gap ASC;

--------------------------------------------------------------------------------------------

---PEAK HIRING SEASONALITY ANALYSIS
--Q-3- What are our historical peak employer registration months across all years?
-- Business Purpose: Build a calendar showing when hiring peaks and slows down.
-- Finding: Hiring spikes after annual performance reviews (April - June) and freezes in December.
-- Recommendation: Launch advertising and client outreach right before busy hiring months start.

 SELECT 
     month,
	   ROUND(AVG(employer_demand),0) AS avg_monthly_employer_demand,
	   ROUND(AVG(jobseekers_supply),0) AS avg_monthly_jobseeker_supply
 FROM  workforce_data 
 GROUP BY month,month_order_id
 ORDER BY month_order_id


-------------------------------------------------------------------------------------------------------------

-- YEAR-OVER-YEAR(YOY) Market Trajectory
--Q-4- Is the overall talent economy expanding or shrinking from 2023 to 2025?
-- Business Purpose: Check if total job hiring is growing or shrinking each year.
-- Finding: Overall jobseeker registrations continue to grow while job creation stays mostly flat.
-- Recommendation: Use yearly trends to plan budgets and set realistic hiring goals.

 SELECT 
    record_year,
	SUM(employer_demand) AS total_annual_employer_demand,
	SUM(jobseekers_supply) AS total_annual_jobseekers_supply,
	(SUM(jobseekers_supply) - SUM(employer_demand)) AS annual_net_surplus
  FROM  workforce_data 
 GROUP BY record_year
 ORDER BY record_year

 ----------------------------------------------------------------------------------------------------------------

--Q-5- How are our sourcing environments distributed across the dataset?
-- Business Purpose: Check how often the hiring market is balanced versus when it hits a crisis (surplus or shortage).
-- Finding: Shows how many months operate in severe surplus, deficit, or balance.
-- Recommendation: Keep a ready list of pre-screened applicants so we are always prepared for sudden hiring spikes.

 SELECT Operational_status,
     COUNT(*) AS total_months_recorded,
	 ROUND(AVG(competition_ratio),2) AS group_avg_competition_ratio
 FROM workforce_data 
 GROUP BY Operational_status
 ORDER BY total_months_recorded DESC
   

-------------------------------------------------- THE END -------------------------------------------------------------------
























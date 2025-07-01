
-- 1 table query
 
--pulling the 2011 values for each location, converting to numeric values
 WITH baseline_values AS (
    SELECT
        location,
        median_household_income_val::text::numeric AS baseline_income,
        median_gross_rent_val::text::numeric AS baseline_rent     
    FROM
        riverwest_med_household_income_gross_rent2     
    WHERE
        year = 2011 
    )  
    SELECT
        r.location,
        r.year,
        -- Why are you double casting??
        r.median_household_income_val::numeric AS income_val, 
        ROUND( (r.median_household_income_val::numeric - b.baseline_income) / b.baseline_income * 100, 2     ) AS income_pct_change_from_2011, --calculates pct change from 2011 baseline values
        r.median_gross_rent_val::text::numeric AS rent_val,
        ROUND(         (r.median_gross_rent_val::text::numeric - b.baseline_rent)         / b.baseline_rent * 100,
        2     ) AS rent_pct_change_from_2011  
    FROM
        riverwest_med_household_income_gross_rent2 r 
    JOIN
        baseline_values b     
            ON r.location = b.location 
    WHERE
        r.year >= 2011 
    ORDER BY
        r.location,
        r.year;
 
 ---2 table query
--looking at pearson's correlation coefficient between percent pop with bachelor degree or higher and median household income values
  SELECT
        i.location,
        CORR(i.median_household_income_val::numeric,
        e.pct_bachelor_degree_or_higher_val::numeric) AS pearson_corr 
    FROM
        riverwest_med_household_income i 
    JOIN
        riverwest_pct_educational_attainment e 
            ON i.location = e.location 
            AND i.year = e.year --joins based on location AND year
    GROUP BY
        i.location;

--- Subquery
 ---comparing rent by RW zip code to the citywide rent and calculating change per year
WITH zip_rent AS (
    SELECT
        location,
        year,
        median_gross_rent_val::text::numeric AS rent     
    FROM
        riverwest_med_household_income_gross_rent2     
    WHERE
        location IN ('53212', '53202', '53211') 
    ), city_rent AS (
    SELECT
        year,
        median_gross_rent_val::text::numeric AS city_rent     
    FROM
        riverwest_med_household_income_gross_rent2     
    WHERE
        location = 'Milwaukee' 
    ), zip_yoy_change AS 
    (   
    SELECT --gets citywide rent data for milwaukee to compare with my 3 zip codes 
        location,
        year,
        rent,
        LAG(rent) OVER (PARTITION --calculates pct change in rent year after year, compared to the previous yr
    BY
        location 
    ORDER BY
        year) AS prev_year_rent,
        ROUND(             (rent - LAG(rent) OVER (PARTITION 
    BY
        location 
    ORDER BY
        year))              / NULLIF(LAG(rent) OVER (PARTITION 
    BY
        location 
    ORDER BY
        year),
        0) * 100,
        2         ) AS rent_pct_change     
    FROM
        zip_rent ), city_yoy_change AS (     SELECT
        year,
        city_rent,
        LAG(city_rent) OVER (
    ORDER BY
        year) AS prev_year_rent,
        ROUND(             (city_rent - LAG(city_rent) OVER (
    ORDER BY
        year))              / NULLIF(LAG(city_rent) OVER (
    ORDER BY
        year),
        0) * 100,
        2         ) AS city_pct_change     
    FROM
        city_rent )  SELECT
        z.location,
        z.year,
        z.rent,
        z.prev_year_rent,
        z.rent_pct_change,
        c.city_rent,
        c.prev_year_rent AS city_prev_year_rent,
        c.city_pct_change 
    FROM
        zip_yoy_change z 
    JOIN
        city_yoy_change c 
            ON z.year = c.year 
    ORDER BY
        z.location,
        z.year;
    
 
 ---spatial query
--calculating percent growth from 2011 to 2023 in rent values
 WITH rent_by_zip AS (     SELECT
        location,
        MAX(CASE 
            WHEN year = 2011 THEN median_gross_rent_val::text::numeric 
        END) AS rent_2011,
        MAX(CASE 
            WHEN year = 2023 THEN median_gross_rent_val::text::numeric 
        END) AS rent_2023     --only interested in the start year and end year of data for comparison between zip codes
    FROM
        riverwest_med_household_income_gross_rent2     
    WHERE
        location ~ '^\d{5}$'  -- restrict to ZIPs only     
    GROUP BY
        location ), rent_change AS (     SELECT
        location,
        rent_2011,
        rent_2023,
        ROUND(((rent_2023 - rent_2011) / NULLIF(rent_2011, -- actual pct change calculation
        0)) * 100,
        2) AS rent_pct_change     
    FROM
        rent_by_zip ), final_map AS (     SELECT
        r.location,
        r.rent_pct_change,
        s.geom     
    FROM
        rent_change r     
    JOIN
        tiger_line_2012 s         -- joins to the spatial data shapefile to plot the pct change on the actual, physical zip codes
            ON r.location = s.zcta5ce10   )  SELECT
            * 
    FROM
        final_map;
 
 
 

 ---additional:
  
  SELECT
    location,
    CORR(black_pop::numeric, white_pop::numeric) AS pearson_corr --computes pearson's corrrelation coefficient between black and white populations for each location
FROM
    riverwest_population_demographics
GROUP BY location;




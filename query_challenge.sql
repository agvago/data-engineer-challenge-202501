

//1
//Number of employees hired for each job and department in 2021 divided by quarter. The
//table must be ordered alphabetically by department and job.

SELECT
	COALESCE(d.department_name,'N/A') department,
	COALESCE(j.job_name,'N/A') job,
	COUNT(CASE WHEN EXTRACT(QUARTER FROM e.hire_datetime) = 1 THEN e.id END) AS Q1,
	COUNT(CASE WHEN EXTRACT(QUARTER FROM e.hire_datetime) = 2 THEN e.id END) AS Q2,
	COUNT(CASE WHEN EXTRACT(QUARTER FROM e.hire_datetime) = 3 THEN e.id END) AS Q3,
	COUNT(CASE WHEN EXTRACT(QUARTER FROM e.hire_datetime) = 4 THEN e.id END) AS Q4
FROM stage.departments d
LEFT JOIN stage.hired_employees e on e.department_id = d.id
	AND EXTRACT(YEAR FROM e.hire_datetime) = 2021
LEFT JOIN stage.jobs j on e.job_id = j.id
GROUP BY d.department_name, j.job_name
ORDER BY department ASC, job ASC
;

///2
//List of ids, name and number of employees hired of each department that hired more
//employees than the mean of employees hired in 2021 for all the departments, ordered
//by the number of employees hired (descending).

WITH departent_hiring_cte AS (
	SELECT
	e.department_id,
	d.department_name,
	COUNT(e.id) total_count
	FROM stage.hired_employees e
	LEFT JOIN stage.departments d on e.department_id = d.id
	GROUP BY e.department_id, d.department_name
)
SELECT * FROM departent_hiring_cte
WHERE total_count > (SELECT
	AVG(total_count) as avg_hired
FROM departent_hiring_cte)
ORDER BY total_count DESC
;
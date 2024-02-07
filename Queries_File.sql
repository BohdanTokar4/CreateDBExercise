-- Choosing database
USE CompanyDB;


-- 1. Retrieve a list of all roles in the company, which should include the number of employees for each of role assigned
SELECT DISTINCT 
	pa.EmployeeRole,
	COUNT(pa.EmployeeID) AS Quantity 
FROM ProjectAssigments pa
GROUP BY EmployeeRole;


/* In my database there are equal quantity of all roles (which is unrealistic
but it doesn`t matter in this case ), except for one. One role does not have
any assigned employee to it, which might happen in real database and what is
asked in next task 2. */


-- 2. Get roles which has no employees assigned
SELECT 
	EmployeeRole,
	EmployeeID
FROM ProjectAssigments
WHERE EmployeeID IS NULL;
/* As we can see, there is only one role in my database which has no employees
assigned - Data Quality Engineer. But it`s important role, so Engineer needs to
be hired. And I is the best candidate =) */


-- 3. Get projects list where every project has list of roles supplied with number of employees
SELECT
	ProjectsList.ProjectID, 
	ProjectName, 
	EmployeeRole,
	COUNT(ProjectAssigments.EmployeeRole) AS NumberOfEmployees
FROM ProjectsList
LEFT JOIN ProjectAssigments
	ON ProjectsList.ProjectID = ProjectAssigments.ProjectID
GROUP BY ProjectName, EmployeeRole, ProjectsList.ProjectID;
GO


-- 4. For every project count how many tasks there are assigned for every employee in average.
/* As I understand, this condition asks me to show how many tasks are assigned for employees
on projects, in average. I mean, for example, let`s imagine there is a project with three
assigned employees. First employee have 7 tasks, second have 3 tasks, third have 2 tasks. 
So in average, there are 4 assigned tasks per employee on this project. That`s what my
query counting. */
SELECT
	pl.ProjectID,
	pl.ProjectName,
	CAST(AVG(1.0 * pl.TaskQuantity / temp.EmployeeCounter) -- I multiply by 1.0 to provide division with decimal. So it guarantees that we get value in float. I used float, because there are small amount of tasks per employee in my db
	AS DECIMAL (4, 2)) AS AvgTasksPerEmployee -- This value is limited to 99.99, by the way, in my database no employee has more than 10 tasks. But if there would be a much more tasks, the number 4 should be changed to bigger value
FROM ProjectsList pl
JOIN (
	SELECT
		ProjectID,
		COUNT(DISTINCT EmployeeID) AS EmployeeCounter -- Joining the subquery which counting unique quantity of employees for each project
	FROM Tasks
	GROUP BY ProjectID
	)
AS temp ON pl.ProjectID = temp.ProjectID
GROUP BY 
	pl.ProjectID,
	pl.ProjectName;
GO


-- 5. Determine duration for each project
/* I`m counting duration even if project is still open.
In this case, I count duration from creation date to today*/
SELECT
	pl.ProjectID,
	pl.ProjectName,
	DATEDIFF(dd, ProjectCreationDate, COALESCE(ProjectCloseDate, GETDATE()))
	AS DurationInDays
FROM ProjectsList pl
ORDER BY ProjectID;
GO

 
-- 6. Identify which employees has the lowest number tasks with non-closed statuses.
-- There are included employees without any projects and/or tasks assigned.
SELECT e.EmployeeID, TasksNum = COUNT(t.TaskID) 
FROM Employees e
LEFT JOIN Tasks t
ON e.EmployeeID = t.EmployeeID
WHERE COALESCE(t.TaskStatus,'Not assigned') !='accepted (closed)' -- I have employees without any tasks assigned, so to show that they zero tasks I used this;
GROUP BY e.EmployeeID
ORDER BY 2 ASC; -- Order by second column in the results table, equal to ORDER BY TasksNum
/* As it not mentioned in the homework conditions, that should I 
include employees without any non-closed task or not, I decided
to  include them too. So, we can see zeros in TasksNum column. */


-- 7. Identify which employees has the most tasks with non-closed statuses with failed deadlines.
/* There are shown only employees with non-closed tasks with failed deadlines.
Employees without any failed deadlines are not shown in results, despite the 
fact that they may have tasks with non-closed status. */
SELECT
	e.EmployeeID,
	e.EmployeeFirstName,
	e.EmployeeLastName,
	COUNT (t.TaskID) AS NonClosedAndFailedDeadline
FROM Employees e
JOIN Tasks t
	ON e.EmployeeID = t.EmployeeID
WHERE t.TaskStatus != 'accepted (closed)' 
AND DeadlineDate < GETDATE()
GROUP BY
	e.EmployeeID,
	e.EmployeeFirstName,
	e.EmployeeLastName
ORDER BY NonClosedAndFailedDeadline DESC;
GO
-- DeadlineDate is generated randomly


-- 8. Move forward deadline for non-closed tasks in 5 days.
UPDATE Tasks
SET DeadlineDate = DATEADD(DAY, 5, DeadlineDate)
WHERE TaskStatus != 'accepted (closed)';


 -- 9. For each project count how many there are tasks which were not started yet.
SELECT
	pl.ProjectID,
	pl.ProjectName,
	COUNT(
		CASE 
			WHEN t.TaskChangeDate IS NULL
			THEN 1
			ELSE NULL
		END
		) 
	AS NotStartedTasks
FROM ProjectsList pl
JOIN Tasks t ON pl.ProjectID = t.ProjectID
GROUP BY 
	pl.ProjectID,
	pl.ProjectName
ORDER BY NotStartedTasks ASC;
GO
/* I used TaskChangeDate as Start date of the task, because I have no Task Start Date
column in my database. */


-- 10. For each project which has all tasks marked as closed move status to closed. Close date for such project should match close date for the last accepted task.
UPDATE ProjectsList
SET ProjectState = 'closed',
ProjectCloseDate = 
	(
	SELECT MAX(t.TaskChangeDate)
	FROM Tasks t
	WHERE t.ProjectID = ProjectsList.ProjectID
		AND t.TaskStatus NOT IN ('open', 'done', 'need work')
	)
FROM ProjectsList
WHERE ProjectID IN 
	(
	SELECT pl.ProjectID
	FROM ProjectsList pl
	LEFT JOIN Tasks t ON pl.ProjectID = t.ProjectID
	WHERE NOT EXISTS
		(
		SELECT 1
		FROM Tasks
		WHERE ProjectID = pl.ProjectID AND TaskStatus <> 'accepted (closed)'
		)
	);
GO
/* In my database, there is only one project with all closed tasks, it`s project #7 "ZhytomyrianByteForge".
Projects #27,28,29,30 were closed manually by update statement in my database by statements for testing
triggers (which I wrote in the end of database creating script), but tasks of these projects aren`t closed. */


-- 11. Determine employees across all projects which has not non-closed tasks assigned.
/* In my database there are employees without any tasks assigned, as it could be in real
databases. So my query below is checking if employee has any tasks assigned, and if yes,
than it checking are these tasks closed or not. So, in result we see only employees, which
do not have any non-closed tasks. */
SELECT
    e.EmployeeID,
    e.EmployeeFirstName,
    e.EmployeeLastName
FROM Employees e
WHERE NOT EXISTS
	(
    SELECT 1
    FROM Tasks t
    WHERE t.EmployeeID = e.EmployeeID
        AND t.TaskStatus != 'accepted (closed)' -- Here I check if all tasks are closed
	)
AND EXISTS
(
    SELECT 1
    FROM Tasks t2
    WHERE t2.EmployeeID = e.EmployeeID -- Here I check if employee has any assigned tasks at all
);


-- 12. Assign given project task (using task name as identifier) to an employee which has minimum tasks with open status.
UPDATE Tasks
SET EmployeeID = (
    SELECT TOP 1 EmployeeID
    FROM ProjectAssigments pa
    WHERE pa.ProjectID = (SELECT ProjectID FROM Tasks WHERE TaskName = 'New Task')
      AND pa.EmployeeID NOT IN (SELECT EmployeeID FROM Tasks WHERE TaskStatus = 'open' AND ProjectID = pa.ProjectID)
    GROUP BY pa.EmployeeID
    ORDER BY COUNT(pa.EmployeeID) ASC
)
WHERE TaskName = 'New Task';
/* In my database, there`s a few employees with same minimum open tasks quantity,
like it could be in real database. So I used TOP 1 to select only one employee.
Also, please, notice that my query is selecting only from those employees, who is 
assigned to the project, which this task belongs. Query doesn`t selecting from all
employees, because logically we can`t assign task from one project to the employee
which assigned to another project. */
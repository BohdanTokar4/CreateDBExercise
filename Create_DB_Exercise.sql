-- Creating database
CREATE DATABASE CompanyDB;

USE CompanyDB;

-- Creating tables
CREATE TABLE Employees -- I created First and Last names for employees despite the fact it`s not mentioned in the task
(
	EmployeeID int IDENTITY PRIMARY KEY,
	EmployeeFirstName nvarchar(20) NULL,
	EmployeeLastName nvarchar(20) NULL
)
GO

CREATE TABLE ProjectsList -- I didn`t created ProjectDescription because it`s not mentioned in the task
(
	ProjectID int IDENTITY PRIMARY KEY,
	ProjectName nvarchar(50) NOT NULL,
	ProjectCreationDate date DEFAULT GETDATE(),
	ProjectState nvarchar(10) DEFAULT 'open' CHECK (ProjectState IN ('open', 'closed')), -- User can set only 'open' or 'closed' value. Open is default value
	ProjectCloseDate date NULL,
	TaskQuantity int NULL -- Adding TaskQuantity column to store the total number of tasks for each project, according to homework conditions
)
GO

CREATE TABLE ProjectAssigments
(
	ProjectID int NOT NULL,
	EmployeeID int NULL,
	EmployeeRole nvarchar(50) NULL,
	FOREIGN KEY (ProjectID) REFERENCES ProjectsList(ProjectID) ON DELETE NO ACTION,
	FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID) ON DELETE NO ACTION
)
GO


CREATE TABLE Tasks -- I didn`t created TaskDescription because it`s not mentioned in the task
(
	TaskID int IDENTITY PRIMARY KEY,
	TaskName nvarchar(50) NULL,
	TaskCreationDate date NOT NULL,
	DeadlineDate date, -- Explanation is located after this query
	ProjectID int NOT NULL,
	EmployeeID int NOT NULL,
	TaskStatus nvarchar(20) DEFAULT 'open' CHECK (TaskStatus IN ('open', 'done', 'need work', 'accepted (closed)')), -- User can set only from listed values. By default the value is 'open'
	TaskChangeDate date NULL,
	ResponsibleEmployeeID int NULL, -- Responsible employee for changes of TaskStatus
	FOREIGN KEY (ProjectID) REFERENCES ProjectsList(ProjectID) ON DELETE NO ACTION,
	FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID) ON DELETE NO ACTION,
	FOREIGN KEY (ResponsibleEmployeeID) REFERENCES Employees(EmployeeID) ON DELETE NO ACTION,
)
GO
-- Explanation on this triger below is located right after it
CREATE TRIGGER SetDeadline
ON Tasks
AFTER INSERT 
AS
BEGIN
	UPDATE Tasks
	SET DeadlineDate = DATEADD(DAY, CAST(RAND() * (30 - 7) + 7 AS INT), TaskCreationDate)
	WHERE DeadlineDate IS NULL;
END;
GO
/* I added this DeadlineDate computed column because in 2nd part of homework saying I should make
queries with deadline date.
DeadlineDate is getting random date from 7 to 30 days since TaskCreationDate. I used trigger to 
make it generated only one time and saved, and not to be generated again everytime you make any
query to this table and DeadlineDate column. I could just insert manually all deadlines into
this column, or use DATEADD, but I really wanted to make it generated randomly, to make my queries a
bit more creative.
=======================How my DeadlineDate is generated? Explaining==================================
Firstly, RAND() generates random number from 0 (included) to 1(not included exactly 1), than this
number is multiplied to result of 30-7 (this way we gets random number from 0 to 23) and after that
we added +7 to generated value so in result we getting random number from 7 to 30. And because days
are only integer numbers, we using CAST(*our result*, AS INT), to round the value and receive integer 
quantity of days. In the end, we adding this quantity to TaskCreationDate. Long story short,
every task received random deadline date in a  range from 7 to 31 days since task start. I
made it to make filling of the table easier for me. I understand that deadlines in real tasks and 
are not generated randomly, but i just made it for example and a bit easier filling of my DB. */


-- Creating triggers

/* As it`s not clearly understanble for me the condition "Please do not cascade delete and
triggers" in homework, I made my triggers in the way to avoid any cascade actions in the 
tables caused by triggers. So, because of it, some triggers were divided into two triggers */

-- Trigger for close date of the project, if it was closed
-- In my db, projects have no deadline date, so projects are closed only when their state is manually updated by the user
CREATE TRIGGER UpdateProjectCloseDate
ON ProjectsList
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	IF UPDATE(ProjectState)
	BEGIN
		UPDATE ProjectsList
		SET 
			ProjectsList.ProjectCloseDate = 
				CASE
					WHEN ProjectsList.ProjectState = 'closed'
					THEN GETDATE()
					ELSE NULL
				END
		WHERE ProjectID IN (SELECT ProjectID FROM inserted);
	END
END;
GO
/* In case project has been closed it should include close date. My trigger above checks 
if ProjectState was updated by the UPDATE query. Than if state is 'closed', trigger will
update ProjectCloseDate by setting the current date. The trigger updates the field based
on the ProjectState value in the row to be updated */


-- Trigger for task quantity for every project
-- Update TaskQuantity for projects affected by the insert
CREATE TRIGGER UpdateTaskQuantityByInsert
ON Tasks
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE ProjectsList
	SET TaskQuantity = 
	(
		SELECT COUNT(*)
		FROM Tasks
		WHERE Tasks.ProjectID = ProjectsList.ProjectID
	)
	WHERE ProjectID IN (SELECT ProjectID FROM inserted);
END;
GO

-- Update TaskQuantity for projects affected by the delete
CREATE TRIGGER UpdateTaskQuantityByDelete
ON Tasks
AFTER DELETE
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE ProjectsList
	SET TaskQuantity =
	(
		SELECT COUNT(*)
		FROM Tasks
		WHERE Tasks.ProjectID = ProjectsList.ProjectID
	)
	WHERE ProjectID IN (SELECT ProjectID FROM deleted);
END;
GO
/* Given that every project includes some number of tasks. So I created the Trigger below, 
which counting all tasks for each project and updating TaskQuantity value in Projects table 
after task was inserted or deleted. As it mentioned that every project have some  number 
of tasks, my trigger does not consider the situation when project have no tasks at the 
current moment. */

-- Triggers for updating the TaskChangeDate and ResponsibleEmployeeID, every time after task status update
-- Trigger for task change date
CREATE TRIGGER UpdateTaskChangeDate
ON Tasks
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	IF UPDATE(TaskStatus)
	BEGIN
		UPDATE Tasks
		SET Tasks.TaskChangeDate = 
				CASE
					WHEN Tasks.TaskStatus IN ('open', 'done', 'need work', 'accepted (closed)')
					THEN GETDATE()
					ELSE NULL
				END
		WHERE TaskID IN (SELECT TaskID FROM inserted);
	END
END;
GO

-- Trigger for task responsible employee
CREATE TRIGGER UpdateResponsibleEmployeeID
ON Tasks
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE Tasks
	SET ResponsibleEmployeeID = inserted.EmployeeID
	FROM inserted
	WHERE Tasks.TaskID = inserted.TaskID
		AND inserted.EmployeeID IS NOT NULL;
END;
GO
/* This triggers above are updating TaskChangeDate and ResponsibleEmployee after the
TaskStatus changes. The triggers checks whether the TaskStatus column has been updated.
If yes, first trigger updates TaskChangeDate with current date and second one is 
setting a ResponsibleEmployee  with a EmployeeID assigned to the task. In the context
of our homework, this is not entirely clear to me - a responsible employee is the same
employee who is assigned for task or another employee and which one exactly. */

/* I could make these triggers more effective and resource-saving but it will cause 
some cascade actions in my triggers, what is forbidden in homework condition: 'Please
do not cascade delete and  triggers'. By the way, it`s not clearly understandable for me,
should I use cascade  triggers in this task, or shouldn`t, or shouldn`t I use triggers
at all. So, in my humble opinion, I made it in the most effective and relevant to the
task conditions way. There are no cascade updates or deletes in the triggers above. */


-- Filling database with test data

-- Fillint the Employees table
INSERT INTO Employees (EmployeeFirstName, EmployeeLastName)
VALUES ('Svyatoslav', 'Igorovich'),
       ('Volodymyr', 'Velykyi'),
       ('Yaroslav', 'Mudriy'),
	   ('Nestor', 'Litopysec'),
	   ('Danylo', 'Halyckiy'),
	   ('Dmytro', 'Vishneveckiy'),
	   ('Ivan', 'Fedorov'),
       ('Konstyantyn', 'Ostrozkiy'),
	   ('Petro', 'Sagaydachniy'),
	   ('Bohdan', 'Hmelnyckiy'),
	   ('Petro', 'Mogyla'),
	   ('Ivan', 'Vigovskiy'),
       ('Ivan', 'Mazepa'),
	   ('Pylyp', 'Orlyk'),
	   ('Feofan', 'Prokopovych'),
	   ('Olga', 'Knyaginya'),
	   ('Hrihoriy', 'Skovoroda'),
       ('Mykola', 'Gogol'),
	   ('Ivan', 'Kotlyarevskiy'),
	   ('Taras', 'Shevchenko'),
	   ('Platon', 'Symyrenko'),
	   ('Myhaylo', 'Dragomanov'),
       ('Mykola', 'Lysenko'),
       ('Ivan', 'Pulyui'),
	   ('Illya', 'Mechnikov'),
	   ('Mariya', 'Zankovecka'),
	   ('Ivan', 'Franko'),
	   ('Volodymyr', 'Vernadskiy'),
       ('Vladyslav', 'Gorodeckiy'),
	   ('Olga', 'Kobilyanska'),
	   ('Myhaylo', 'Kocyubinskiy'),
	   ('Myhaylo', 'Grushevskiy'),
	   ('Lesya', 'Ukrainka'),
       ('Pavlo', 'Skoropadskiy'),
	   ('Mykola', 'Leontovych'),
	   ('Kazymyr', 'Malevych'),
	   ('Symon', 'Petlyura'),
	   ('Volodymyr', 'Vynnychenko'),
       ('Dmytro', 'Doncov'),
	   ('Myhaylo', 'Tereshenko'),
	   ('Les', 'Kurbas'),
	   ('Nestor', 'Mahno'),
	   ('Igor', 'Sikorskiy'),
	   ('Evhen', 'Konovalec'),
	   ('Mykola', 'Hvylyoviy'),
	   ('Olexander', 'Dovzhenko'),
	   ('Borys', 'Lyatoshinskiy'),
	   ('Olena', 'Teliga'),
	   ('Serhiy', 'Korolev'),
	   ('Roman', 'Shuhevych'),
	   ('Stepan', 'Bandera'),
	   ('Andriy', 'Melnik'),
	   ('Mykola', 'Amosov'),
	   ('Lina', 'Kostenko'),
	   ('Vasyl', 'Stus'),
	   ('Bohdan', 'Stupka'),
	   ('Taras', 'Bulba'),
	   ('Vyacheslav', 'Chornovil'),
	   ('Taras', 'Bulba-Borovec'),
	   ('Yaroslav', 'Stecko'),
	   ('Pavlo', 'Shandruk');

-- Filling the ProjectList table
INSERT INTO ProjectsList (ProjectName, ProjectCreationDate)
VALUES ('ZhytomyrConnect', '2024-01-25'),
		('LvivTechInnovation', '2024-01-26'),
		('CarpathianDataWeave', '2024-01-24'),
		('DniproByteCraft', '2024-01-10'),
		('HutsulCloudQuest', '2024-01-22'),
		('PoltavaTechVortex', '2024-01-23'),
		('ZhytomyrianByteForge', '2024-01-13'),
		('ChernihivTechWave', '2024-01-19'),
		('OdessaCyberHarbor', '2024-01-15'),
		('ZakarpattyaSpark', '2024-01-16'),
		('KyivianMatrixProject', '2024-01-18'),
		('CarpathianCipherTech', '2024-01-12'),
		('OdesaTechCraft', '2024-01-11'),
		('LvivDataLoom', '2024-01-17'),
		('HutsulHiveInnovate', '2024-01-08'),
		('PodolianByteBurst', '2024-01-09'),
		('ChernihivNexaInnovation', '2024-01-05'),
		('KyivTechQuotient', '2024-01-04'),
		('TranscarpathianDataZenith', '2024-01-03'),
		('ZhytomyrianByteVista', '2024-01-01'),
		('CarpathianSphinxInnovate', '2024-01-02'),
		('KyivTechQuest', '2023-12-29'),
		('PoltavaCodeSculpt', '2023-12-25'),
		('ZhytomyrianDataForge', '2023-12-20'),
		('HutsulByteBreezeInnovate', '2023-12-14'),
		('KyivianTechSphere', '2023-12-12'),
		('ZakarpattyaByteCraftProject', '2023-12-06'),
		('LvivianQuantumQuasarTech', '2023-12-01'),
		('ChernihivianSparkSprint', '2023-11-11'),
		('ZhytomyrianTechTide', '2023-10-29');

-- Filling the ProjectAssigment table
INSERT INTO ProjectAssigments (ProjectID, EmployeeID, EmployeeRole) -- There`re only few roles for simplifying
VALUES (1, 23, 'Manager'),
		(1, 11, 'Developer'),
		(1, 45, 'Tester'),
		(1, 26, 'Designer'),
		(1, 50, 'Designer'),
		(2, 56, 'Analyst'),
		(2, 5, 'Designer'),
		(2, 18, 'Manager'),
		(2, 21, 'Manager'),
		(3, 39, 'Tester'),
		(3, 21, 'Manager'),
		(3, 31, 'Developer'),
		(3, 10, 'Developer'),
		(4, 12, 'Developer'),
		(4, 33, 'Designer'),
		(4, 60, 'Tester'),
		(4, 28, 'Tester'),
		(5, 8, 'Analyst'),
		(5, 28, 'Manager'),
		(5, 43, 'Analyst'),
		(5, 23, 'Analyst'),
		(6, 50, 'Developer'),
		(6, 14, 'Tester'),
		(6, 2, 'Designer'),
		(6, 1, 'Designer'),
		(7, 20, 'Designer'),
		(7, 29, 'Analyst'),
		(7, 24, 'Manager'),
		(7, 45, 'Manager'),
		(8, 34, 'Manager'),
		(8, 9, 'Developer'),
		(8, 37, 'Developer'),
		(8, 59, 'Developer'),
		(9, 4, 'Tester'),
		(9, 35, 'Analyst'),
		(9, 57, 'Tester'),
		(9, 15, 'Tester'),
		(10, 15, 'Designer'),
		(10, 30, 'Manager'),
		(10, 12, 'Analyst'),
		(10, 13, 'Analyst'),
		(11, 48, 'Developer'),
		(11, 7, 'Tester'),
		(11, 47, 'Designer'),
		(11, 54, 'Designer'),
		(12, 26, 'Analyst'),
		(12, 55, 'Designer'),
		(12, 16, 'Manager'),
		(12, 21, 'Manager'),
		(13, 2, 'Manager'),
		(13, 43, 'Developer'),
		(13, 38, 'Developer'),
		(13, 48, 'Developer'),
		(14, 19, 'Tester'),
		(14, 49, 'Analyst'),
		(14, 53, 'Tester'),
		(14, 8, 'Tester'),
		(15, 10, 'Designer'),
		(15, 51, 'Manager'),
		(15, 3, 'Analyst'),
		(15, 41, 'Analyst'),
		(16, 22, 'Developer'),
		(16, 53, 'Tester'),
		(16, 44, 'Designer'),
		(16, 17, 'Designer'),
		(17, 37, 'Analyst'),
		(17, 46, 'Designer'),
		(17, 25, 'Manager'),
		(17, 33, 'Manager'),
		(18, 18, 'Manager'),
		(18, 38, 'Developer'),
		(18, 58, 'Developer'),
		(18, 56, 'Developer'),
		(19, 42, 'Tester'),
		(19, 59, 'Analyst'),
		(19, 19, 'Tester'),
		(19, 6, 'Tester'),
		(20, 31, 'Designer'),
		(20, 1, 'Manager'),
		(20, 51, 'Analyst'),
		(20, 42, 'Analyst'),
		(21, 27, 'Developer'),
		(21, 60, 'Tester'),
		(21, 29, 'Designer'),
		(21, 9, 'Designer'),
		(22, 26, 'Analyst'),
		(22, 44, 'Designer'),
		(22, 11, 'Manager'),
		(22, 30, 'Manager'),
		(23, 13, 'Manager'),
		(23, 3, 'Developer'),
		(23, 49, 'Developer'),
		(23, 52, 'Developer'),
		(24, 58, 'Tester'),
		(24, 17, 'Analyst'),
		(24, 5, 'Tester'),
		(24, 4, 'Tester'),
		(25, 24, 'Designer'),
		(25, 54, 'Manager'),
		(25, 35, 'Analyst'),
		(25, 37, 'Analyst'),
		(26, 40, 'Developer'),
		(26, 32, 'Tester'),
		(26, 22, 'Designer'),
		(26, 20, 'Designer'),
		(27, 47, 'Analyst'),
		(27, 14, 'Manager'),
		(27, 6, 'Designer'),
		(27, 27, 'Manager'),
		(28, 52, 'Manager'),
		(28, 39, 'Developer'),
		(28, 16, 'Developer'),
		(28, 46, 'Developer'),
		(29, 25, 'Tester'),
		(29, 14, 'Analyst'),
		(29, 55, 'Tester'),
		(29, 32, 'Tester'),
		(30, 7, 'Analyst'),
		(30, 41, 'Designer'),
		(30, 19, 'Analyst'),
		(30, NULL, 'Data Quality Engineer');

-- Filling the Tasks table
INSERT INTO Tasks (TaskName, TaskCreationDate, ProjectID, EmployeeID)
VALUES ('Codebase Cleanup', '2024-01-24', 1, 23),
		('Database Optimization Task', '2024-01-23', 1, 11),
		('UI/UX Redesign Sprint', '2024-01-22', 1, 45),
		('Automated Testing Implementation', '2024-01-21', 1, 26),
		('Cybersecurity Vulnerability Hunt', '2024-01-20', 1, 11),
		('API Integration Assignment', '2024-01-19', 1, 23),
		('Performance Tuning Exercise', '2024-01-18', 2, 56),
		('Mobile App Localization Project', '2024-01-17', 2, 5),
		('System Integration Testing', '2024-01-16', 2, 18),
		('User Experience Enhancement Sprint', '2024-01-15', 2, 18),
		('Automated Security Scanning', '2024-01-14', 2, 21),
		('Database Schema Refinement', '2024-01-13', 2, 21),
		('Mobile App Accessibility Testing', '2024-01-12', 2, 21),
		('Agile Sprint Planning', '2024-01-11', 3, 39),
		('Code Review and Refactoring', '2024-01-10', 3, 39),
		('UI Prototype Development', '2024-01-09', 3, 21),
		('Cloud Infrastructure Optimization', '2024-01-08', 3, 31),
		('Bug Fixing and Patch Deployment', '2024-01-07', 3, 10),
		('Network Performance Monitoring', '2024-01-06', 3, 10),
		('Feature Implementation and Testing', '2024-01-05', 4, 12),
		('DevOps Pipeline Automation', '2024-01-04', 4, 33),
		('API Documentation Review', '2024-01-03', 4, 60),
		('Security Incident Response Drill', '2024-01-02', 4, 28),
		('Continuous Deployment Setup', '2024-01-01', 4, 28),
		('Cross-browser Compatibility Validation', '2023-12-31', 4, 28),
		('Serverless Architecture Implementation', '2023-12-30', 4, 28),
		('Machine Learning Model Training', '2023-12-29', 4, 28),
		('User Interface Redesign Sprint', '2023-12-28', 5, 8),
		('Automated API Testing Implementation', '2023-12-27', 5, 43),
		('Cybersecurity Vulnerability Scanning', '2023-12-26', 5, 23),
		('REST API Integration Task', '2023-12-25', 6, 14),
		('Performance Testing and Optimization', '2023-12-24', 6, 14),
		('Mobile App Localization Enhancement', '2023-12-23', 6, 14),
		('AI-driven Image Recognition Module', '2023-12-22', 16, 2),
		('Continuous Compliance Monitoring', '2023-12-21', 6, 1),
		('GraphQL Schema Optimization', '2023-12-20', 7, 20),
		('Cloud Resource Cleanup Automation', '2023-12-19', 7, 29),
		('Federated Identity Management', '2023-12-18', 7, 24),
		('Real-time Collaboration Module', '2023-12-17', 7, 45),
		('Blockchain Smart Contract Development', '2023-12-16', 7, 45),
		('Codebase Security Auditing', '2023-12-15', 8, 34),
		('IoT Device Integration Challenge', '2023-12-14', 8, 9),
		('Serverless REST API Documentation', '2023-12-13', 8, 37),
		('Progressive Web App SEO Optimization', '2023-12-12', 8, 59),
		('Chaos Engineering Experimentation', '2023-12-11', 9, 4),
		('AI-powered Predictive Analytics Module', '2023-12-10', 9, 35),
		('Cloud Service Dependency Mapping', '2023-12-09', 9, 57),
		('Infrastructure Scaling Strategy', '2023-12-08', 9, 15),
		('Codebase Documentation Enhancement', '2023-12-07', 10, 15),
		('API Gateway Implementation Task', '2023-12-06', 10, 15),
		('Virtual Reality (VR) Interaction Design', '2023-12-05', 10, 30),
		('Serverless Backend Autoscaling', '2023-12-04', 10, 12),
		('Edge Computing Integration', '2023-12-03', 10, 13),
		('Secure Software Development Lifecycle', '2023-12-02', 11, 48),
		('Mobile App Performance Profiling', '2023-12-01', 11, 7),
		('AI-driven Image Recognition Task', '2023-11-30', 11, 47),
		('User Authentication System Enhancement', '2023-11-29', 11, 54),
		('Database Schema Refactoring', '2023-11-28', 12, 26),
		('Security Audit and Penetration Testing', '2023-11-27', 12, 55),
		('User Interface Redesign Sprint', '2023-11-26', 12, 16),
		('Automated API Testing Implementation', '2023-11-25', 12, 21),
		('Cybersecurity Vulnerability Scanning', '2023-11-24', 13, 2),
		('REST API Integration Task', '2023-11-23', 13, 43),
		('Performance Testing and Optimization', '2023-11-22', 13, 38),
		('Mobile App Localization Enhancement', '2023-11-21', 13, 48),
		('AI-driven Image Recognition Module', '2023-11-20', 14, 19),
		('Continuous Compliance Monitoring', '2023-11-19', 14, 49),
		('GraphQL Schema Optimization', '2023-11-18', 14, 53),
		('Cloud Resource Cleanup Automation', '2023-11-17', 14, 8),
		('Federated Identity Management', '2023-11-16', 14, 8),
		('Real-time Collaboration Module', '2023-11-15', 15, 10),
		('Blockchain Smart Contract Development', '2023-11-14', 15, 51),
		('Codebase Security Auditing', '2023-11-13', 15, 3),
		('IoT Device Integration Challenge', '2023-11-12', 15, 41),
		('Serverless REST API Documentation', '2023-11-11', 16, 22),
		('Progressive Web App SEO Optimization', '2023-11-10', 16, 53),
		('Chaos Engineering Experimentation', '2023-11-09', 16, 44),
		('AI-powered Predictive Analytics Module', '2023-11-08', 16, 17),
		('Cloud Service Dependency Mapping', '2023-11-07', 17, 37),
		('Infrastructure Scaling Strategy', '2023-11-06', 17, 46),
		('Codebase Documentation Enhancement', '2023-11-05', 17, 25),
		('API Gateway Implementation Task', '2023-11-04', 17, 33),
		('Virtual Reality (VR) Interaction Design', '2023-11-03', 18, 18),
		('Serverless Backend Autoscaling', '2023-11-02', 18, 18),
		('Edge Computing Integration', '2023-11-01', 18, 38),
		('Secure Software Development Lifecycle', '2023-10-31', 18, 58),
		('Mobile App Performance Profiling', '2023-10-30', 18,56),
		('AI-driven Image Recognition Task', '2023-10-29', 19, 42),
		('User Authentication System Enhancement', '2023-10-28', 19, 59),
		('Database Schema Refactoring', '2023-10-27', 19, 19),
		('Security Audit and Penetration Testing', '2023-10-26', 19, 19),
		('User Interface Redesign Sprint', '2023-10-25', 19, 6),
		('Automated API Testing Implementation', '2023-10-24', 19, 6),
		('Cybersecurity Vulnerability Scanning', '2023-10-23', 20, 31),
		('REST API Integration Task', '2023-10-22', 20, 1),
		('Performance Testing and Optimization', '2023-10-21', 20, 1),
		('Mobile App Localization Enhancement', '2023-10-20', 20, 51),
		('AI-driven Image Recognition Module', '2023-10-19', 20, 42),
		('Continuous Compliance Monitoring', '2023-10-18', 21, 27),
		('GraphQL Schema Optimization', '2023-10-17', 21, 60),
		('Cloud Resource Cleanup Automation', '2023-10-16', 21, 29),
		('Federated Identity Management', '2023-10-15', 21, 9),
		('Real-time Collaboration Module', '2023-10-14', 22, 26),
		('Blockchain Smart Contract Development', '2023-10-13', 22, 44),
		('Codebase Security Auditing', '2023-10-12', 22, 11),
		('IoT Device Integration Challenge', '2023-10-11', 22, 30),
		('Serverless REST API Documentation', '2023-10-10', 23, 13),
		('Progressive Web App SEO Optimization', '2023-10-09', 23, 3),
		('Chaos Engineering Experimentation', '2023-10-08', 23, 49),
		('AI-powered Predictive Analytics Module', '2023-10-07', 23, 52),
		('Cloud Service Dependency Mapping', '2023-10-06', 24, 58),
		('Infrastructure Scaling Strategy', '2023-10-05', 24, 17),
		('Codebase Documentation Enhancement', '2023-10-04', 24, 5),
		('API Gateway Implementation Task', '2023-10-03', 24, 4),
		('Virtual Reality (VR) Interaction Design', '2023-10-02', 25, 24),
		('Serverless Backend Autoscaling', '2023-10-01', 25, 54),
		('Edge Computing Integration', '2023-09-30', 25, 35),
		('Secure Software Development Lifecycle', '2023-09-29', 25, 35),
		('Mobile App Performance Profiling', '2023-09-28',25, 35),
		('AI-driven Image Recognition Task', '2023-09-27', 25, 35),
		('User Authentication System Enhancement', '2023-09-26', 25, 35),
		('Database Schema Refactoring', '2023-09-25', 25, 35),
		('Security Audit and Penetration Testing', '2023-09-24', 25, 35),
		('User Interface Redesign Sprint', '2023-09-23', 25, 35),
		('Automated API Testing Implementation', '2023-09-22', 25, 35),
		('Cybersecurity Vulnerability Scanning', '2023-09-21', 25, 37),
		('REST API Integration Task', '2023-09-20', 26, 40),
		('Performance Testing and Optimization', '2023-09-19', 26, 32),
		('Mobile App Localization Enhancement', '2023-09-18', 26, 22),
		('AI-driven Image Recognition Module', '2023-09-17', 26, 20),
		('Continuous Compliance Monitoring', '2023-09-16', 27, 47),
		('GraphQL Schema Optimization', '2023-09-15', 27, 14),
		('Cloud Resource Cleanup Automation', '2023-09-14', 27, 6),
		('Federated Identity Management', '2023-09-13', 27, 27),
		('Real-time Collaboration Module', '2023-09-12', 28, 52),
		('Blockchain Smart Contract Development', '2023-09-11', 28, 52),
		('Codebase Security Auditing', '2023-09-10', 28, 39),
		('IoT Device Integration Challenge', '2023-09-09', 28, 16),
		('Serverless REST API Documentation', '2023-09-08', 28, 46),
		('Progressive Web App SEO Optimization', '2023-09-07', 28, 25),
		('Chaos Engineering Experimentation', '2023-09-06', 29, 25),
		('AI-powered Predictive Analytics Module', '2023-09-05', 29, 14),
		('Cloud Service Dependency Mapping', '2023-09-04', 29, 55),
		('Infrastructure Scaling Strategy', '2023-09-03', 29, 32),
		('Codebase Documentation Enhancement', '2023-09-02', 30, 7),
		('API Gateway Implementation Task', '2023-09-01', 30, 41),
		('Virtual Reality (VR) Interaction Design', '2023-08-31', 30, 19),
		('Serverless Backend Autoscaling', '2023-08-30', 27, 47),
		('Edge Computing Integration', '2023-08-29', 28, 39),
		('Secure Software Development Lifecycle', '2023-08-28', 21, 9),
		('Mobile App Performance Profiling', '2023-08-27', 6, 14);
		

-- Using of triggers
-- UpdateProjectCloseDate Trigger
UPDATE ProjectsList
SET ProjectState = 'closed'
WHERE ProjectID = 30;

UPDATE ProjectsList
SET ProjectState = 'closed'
WHERE ProjectID IN (29, 28, 27);


-- UpdateTaskQuantityByInsert
INSERT INTO Tasks (ProjectID, EmployeeID, TaskName, TaskCreationDate) 
VALUES (1, 11, 'New Task', GETDATE());

-- UpdateTaskQuantityByDelete
DELETE FROM Tasks 
WHERE TaskID = 151;


-- UpdateTaskChangeDate And UpdateResponsibleEmployeeID
UPDATE Tasks
SET TaskStatus = 'done'
WHERE TaskID = 2;

UPDATE Tasks
SET TaskStatus = 'open'
WHERE TaskID = 3;

UPDATE Tasks
SET TaskStatus = 'need work'
WHERE TaskID = 4;

UPDATE Tasks
SET TaskStatus = 'accepted (closed)'
WHERE TaskID IN ( 8, 11, 15, 16, 19, 20, 25, 29, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 44, 48, 46, 59, 50, 62, 63, 69, 89, 101, 109, 113);

-- To see what triggers changed, we should use these queries
SELECT * 
FROM ProjectsList 
WHERE ProjectState = 'closed';

SELECT TaskQuantity 
FROM ProjectsList;

SELECT * 
FROM Tasks 
WHERE 
	TaskChangeDate IS NOT NULL 
	AND 
	ResponsibleEmployeeID IS NOT NULL;
GO

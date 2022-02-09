--NOTE FOR THIS SCRIPT TO WORK YOU HAVE TO RUN IT IN CHUNKS - CIRCULAR REFERENCES
CREATE TABLE Executives (
	Id INTEGER PRIMARY KEY NOT NULL,
	Name TEXT,
	Description TEXT,
	JudicialId INTEGER,
    FOREIGN KEY (JudicialId) REFERENCES Judicials(Id)
);

CREATE TABLE Legislatives (
	Id INTEGER PRIMARY KEY NOT NULL,
	Name TEXT,
	Description TEXT,
	ExecutiveId INTEGER	,
    FOREIGN KEY (ExecutiveId) REFERENCES Executives(Id)
);

CREATE TABLE Judicials (
	Id INTEGER PRIMARY KEY NOT NULL,
	Name TEXT,
	Description TEXT,
	LegislativeId INTEGER,
    FOREIGN KEY (LegislativeId) REFERENCES Legislatives(Id)
);


INSERT INTO Executives (Name,Description,JudicialId) VALUES
('Police Force','Police',1),
('Border Force','Protecting Australia''s Borders',1),
('ASIC','Aust. Securities & Invesment Commission',1),
('HCCC','Health Care Complaints Commission',1);

INSERT INTO Legislatives (Name,Description,ExecutiveId) VALUES
('Parliment','Make Laws',1),
('Legislative Council','Legislate Laws',1),
('Bicameral','Legislate Council & Assembly',1);


INSERT INTO Judicials (Name,Description,LegislativeId) VALUES
('Magistrates Courts','Magistrates Courts',1),
('High Courts','Magistrates Courts',1),
('Supreme Courts','Protecting Australia''s Borders',1),
('Privy Council','Privy Council',2);



select * from Judicials as j
inner join Executives as e on e.JudicialId  = j.Id
inner join Legislatives as l on l.Id = j.LegislativeId 

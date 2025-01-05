-- File: advanced_museum_database.sql

-- 1. Create the database and enable necessary big data features
CREATE DATABASE MuseumDatabase;
USE MuseumDatabase;

-- Set database engine to InnoDB for transaction support and row-level locking
SET default_storage_engine=InnoDB;

-- Enable partitioning if supported by the RDBMS
-- This helps with performance on large tables
ALTER DATABASE MuseumDatabase DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 2. Advanced schema design with normalization
-- Specimens Table: Stores specimen information
CREATE TABLE Specimens (
    SpecimenID BIGINT AUTO_INCREMENT PRIMARY KEY,
    ScientificName VARCHAR(255) NOT NULL,
    CategoryID INT NOT NULL,
    LocationID INT NOT NULL,
    CatalogedByID INT NOT NULL,
    CollectionDate DATE NOT NULL,
    Description TEXT,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_scientific_name (ScientificName),
    INDEX idx_category (CategoryID),
    INDEX idx_location (LocationID),
    INDEX idx_cataloged_by (CatalogedByID),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID),
    FOREIGN KEY (LocationID) REFERENCES Locations(LocationID),
    FOREIGN KEY (CatalogedByID) REFERENCES Curators(CuratorID)
) PARTITION BY RANGE (YEAR(CollectionDate)) (
    PARTITION p_2020 VALUES LESS THAN (2021),
    PARTITION p_2021 VALUES LESS THAN (2022),
    PARTITION p_2022 VALUES LESS THAN (2023),
    PARTITION p_2023 VALUES LESS THAN (2024),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Categories Table: Normalize categories for specimens
CREATE TABLE Categories (
    CategoryID INT AUTO_INCREMENT PRIMARY KEY,
    CategoryName VARCHAR(100) NOT NULL UNIQUE
);

-- Locations Table: Normalize locations for specimens
CREATE TABLE Locations (
    LocationID INT AUTO_INCREMENT PRIMARY KEY,
    LocationName VARCHAR(255) NOT NULL UNIQUE
);

-- Curators Table: Stores curator details
CREATE TABLE Curators (
    CuratorID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    Email VARCHAR(255) UNIQUE,
    Role VARCHAR(100),
    AssignedSpecimenCount INT DEFAULT 0
);

-- Research Projects Table: Stores project details
CREATE TABLE ResearchProjects (
    ProjectID BIGINT AUTO_INCREMENT PRIMARY KEY,
    ProjectName VARCHAR(255) NOT NULL,
    LeadCuratorID INT,
    Description TEXT,
    StartDate DATE,
    EndDate DATE,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (LeadCuratorID) REFERENCES Curators(CuratorID),
    INDEX idx_project_name (ProjectName)
);

-- 3. Insert sample data efficiently for a large dataset
-- Bulk insert for Categories
INSERT INTO Categories (CategoryName)
VALUES ('Mammal'), ('Bird'), ('Reptile'), ('Fish'), ('Amphibian'), ('Insect'), ('Plant')
ON DUPLICATE KEY UPDATE CategoryName = VALUES(CategoryName);

-- Bulk insert for Locations
INSERT INTO Locations (LocationName)
VALUES 
    ('Savannah, Africa'), 
    ('Virunga Mountains'), 
    ('Sichuan, China'), 
    ('Amazon Rainforest'), 
    ('Arctic Circle')
ON DUPLICATE KEY UPDATE LocationName = VALUES(LocationName);

-- 4. Advanced queries for large datasets
-- Retrieve specimens with pagination
SELECT 
    s.SpecimenID, s.ScientificName, c.CategoryName, l.LocationName, cur.Name AS CatalogedBy, s.CollectionDate
FROM 
    Specimens s
JOIN Categories c ON s.CategoryID = c.CategoryID
JOIN Locations l ON s.LocationID = l.LocationID
JOIN Curators cur ON s.CatalogedByID = cur.CuratorID
ORDER BY s.CollectionDate DESC
LIMIT 100 OFFSET 0;

-- Count specimens by category with efficient grouping
SELECT 
    c.CategoryName, COUNT(*) AS SpecimenCount
FROM 
    Specimens s
JOIN Categories c ON s.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY SpecimenCount DESC;

-- Query to retrieve specimens added in the last year for dynamic reporting
SELECT 
    s.SpecimenID, s.ScientificName, c.CategoryName, l.LocationName, s.CollectionDate
FROM 
    Specimens s
JOIN Categories c ON s.CategoryID = c.CategoryID
JOIN Locations l ON s.LocationID = l.LocationID
WHERE 
    s.CollectionDate >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR);

-- Query for curator workload
SELECT 
    cur.Name, cur.Role, COUNT(s.SpecimenID) AS TotalSpecimens
FROM 
    Curators cur
LEFT JOIN Specimens s ON cur.CuratorID = s.CatalogedByID
GROUP BY cur.CuratorID
ORDER BY TotalSpecimens DESC;

-- 5. Advanced optimization for retrieval and management
-- Add full-text indexing for complex queries
ALTER TABLE Specimens ADD FULLTEXT (ScientificName, Description);

-- Partition pruning for fast query execution
EXPLAIN PARTITIONS
SELECT *
FROM Specimens
WHERE CollectionDate BETWEEN '2022-01-01' AND '2022-12-31';

-- 6. Stored Procedures for frequent operations
DELIMITER //
CREATE PROCEDURE AddSpecimen(
    IN sci_name VARCHAR(255),
    IN category_name VARCHAR(100),
    IN location_name VARCHAR(255),
    IN curator_id INT,
    IN collection_date DATE,
    IN description TEXT
)
BEGIN
    DECLARE category_id INT;
    DECLARE location_id INT;

    -- Retrieve or insert category
    SELECT CategoryID INTO category_id FROM Categories WHERE CategoryName = category_name;
    IF category_id IS NULL THEN
        INSERT INTO Categories (CategoryName) VALUES (category_name);
        SET category_id = LAST_INSERT_ID();
    END IF;

    -- Retrieve or insert location
    SELECT LocationID INTO location_id FROM Locations WHERE LocationName = location_name;
    IF location_id IS NULL THEN
        INSERT INTO Locations (LocationName) VALUES (location_name);
        SET location_id = LAST_INSERT_ID();
    END IF;

    -- Insert specimen
    INSERT INTO Specimens (ScientificName, CategoryID, LocationID, CatalogedByID, CollectionDate, Description)
    VALUES (sci_name, category_id, location_id, curator_id, collection_date, description);
END //
DELIMITER ;

-- Call stored procedure for batch data entry
CALL AddSpecimen(
    'Panthera leo', 
    'Mammal', 
    'Savannah, Africa', 
    1, 
    '2023-01-15', 
    'Large carnivorous mammal.'
);

-- 7. Advanced reporting query for exhibits and research
SELECT 
    rp.ProjectName, COUNT(s.SpecimenID) AS SpecimenCount, cur.Name AS LeadCurator
FROM 
    ResearchProjects rp
LEFT JOIN Curators cur ON rp.LeadCuratorID = cur.CuratorID
LEFT JOIN Specimens s ON cur.CuratorID = s.CatalogedByID
GROUP BY rp.ProjectID
ORDER BY SpecimenCount DESC;

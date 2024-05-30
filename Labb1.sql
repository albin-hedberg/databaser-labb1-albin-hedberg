-----------------------------
-- USE master;
-- ALTER DATABASE BookStore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- DROP DATABASE BookStore;
-----------------------------

CREATE DATABASE BookStore;

USE BookStore;

-- Tables ---------------------------------------------------------------------------------------
CREATE TABLE Authors
(
	[ID] INT PRIMARY KEY,
	[FirstName] NVARCHAR(100) NOT NULL,
	[LastName] NVARCHAR(100) NOT NULL,
	[DateOfBirth] DATE NOT NULL,
	-- format: YYYY-MM-DD
	[DateOfDeath] DATE
	-- format: YYYY-MM-DD
);

CREATE TABLE Books
(
	[ISBN13] NVARCHAR(13) PRIMARY KEY,
	[Title] NVARCHAR(MAX) NOT NULL,
	[Language] NVARCHAR(100),
	[Price] FLOAT NOT NULL,
	[ReleaseDate] DATE NOT NULL,
	-- Extra kolumner
	[Pages] INT NOT NULL,
	[Edition] INT,
	[Format] NVARCHAR(50),
	[Dimensions] NVARCHAR(100),
	[Weight] FLOAT,
	CHECK(LEN(ISBN13) = 13)
);

CREATE TABLE Stores
(
	[ID] INT PRIMARY KEY,
	[Name] NVARCHAR(100) NOT NULL,
	[Address] NVARCHAR(MAX) NOT NULL,
	[PostalCode] VARCHAR(6),
	[City] NVARCHAR(100)
);

CREATE TABLE Genres
(
	[ID] INT PRIMARY KEY,
	[Name] NVARCHAR(50) NOT NULL,
	[Description] NVARCHAR(MAX)
);

CREATE TABLE Customers
(
	[ID] INT PRIMARY KEY,
	[FirstName] NVARCHAR(100) NOT NULL,
	[LastName] NVARCHAR(100) NOT NULL,
	[Email] NVARCHAR(100),
	[Address] NVARCHAR(MAX) NOT NULL,
	[Phone] NVARCHAR(20)
);

CREATE TABLE Reviews
(
	[ID] INT PRIMARY KEY,
	[CustomerID] INT,
	[Text] NVARCHAR(MAX),
	[Rating] INT NOT NULL,
	[DateSubmitted] DATETIME,
	CHECK(Rating >= 0 AND Rating <= 5),
	FOREIGN KEY ([CustomerID]) REFERENCES Customers(ID)
);

CREATE TABLE Publishers
(
	[ID] INT PRIMARY KEY,
	[Name] NVARCHAR(50) NOT NULL
);

-- Junction Tables ------------------------------------------------------------------------------
CREATE TABLE StoresInventory
(
	[StoreID] INT NOT NULL,
	[ISBN] NVARCHAR(13) NOT NULL,
	[Quantity] INT DEFAULT 0,
	PRIMARY KEY ([StoreID], [ISBN]),
	FOREIGN KEY ([StoreID])	REFERENCES Stores(ID),
	FOREIGN KEY ([ISBN])	REFERENCES Books(ISBN13)
);

CREATE TABLE BookAuthors
(
	[ISBN] NVARCHAR(13) NOT NULL,
	[AuthorID] INT NOT NULL,
	PRIMARY KEY ([ISBN], [AuthorID]),
	FOREIGN KEY ([ISBN])		REFERENCES Books(ISBN13),
	FOREIGN KEY ([AuthorID])	REFERENCES Authors(ID)
);

CREATE TABLE BookGenres
(
	[ISBN] NVARCHAR(13) NOT NULL,
	[GenreID] INT NOT NULL,
	PRIMARY KEY ([ISBN], [GenreID]),
	FOREIGN KEY ([ISBN])		REFERENCES Books(ISBN13),
	FOREIGN KEY ([GenreID])		REFERENCES Genres(ID)
);

CREATE TABLE BookReviews
(
	[ISBN] NVARCHAR(13) NOT NULL,
	[ReviewID] INT NOT NULL,
	PRIMARY KEY ([ISBN], [ReviewID]),
	FOREIGN KEY ([ISBN])		REFERENCES Books(ISBN13),
	FOREIGN KEY ([ReviewID])	REFERENCES Reviews(ID)
);

CREATE TABLE BookPublishers
(
	[ISBN] NVARCHAR(13) NOT NULL,
	[PublisherID] INT NOT NULL,
	PRIMARY KEY ([ISBN], [PublisherID]),
	FOREIGN KEY ([ISBN])		REFERENCES Books(ISBN13),
	FOREIGN KEY ([PublisherID])	REFERENCES Publishers(ID)
);

GO;

-- Views ----------------------------------------------------------------------------------------
CREATE OR ALTER VIEW vTitlesPerAuthor
AS
	SELECT
		CONCAT(Authors.FirstName, ' ', Authors.LastName) AS [Namn],
		CASE
		WHEN Authors.DateOfDeath IS NULL
		THEN CAST(DATEDIFF(YEAR, Authors.DateOfBirth, GETDATE()) AS NVARCHAR) + ' år'
		ELSE CAST(DATEDIFF(YEAR, Authors.DateOfBirth, Authors.DateOfDeath) AS NVARCHAR) + ' år (Död)'
	END AS [Ålder],
		COUNT(DISTINCT Books.ISBN13) AS [Titlar],
		FORMAT(SUM(Books.Price * StoresInventory.Quantity), '0,0.00:-') AS [Lagervärde (SEK)]
	FROM Authors
		JOIN BookAuthors ON BookAuthors.AuthorID = Authors.ID
		JOIN Books ON Books.ISBN13 = BookAuthors.ISBN
		JOIN StoresInventory ON StoresInventory.ISBN = Books.ISBN13
	GROUP BY Authors.FirstName, Authors.LastName, Authors.DateOfBirth, Authors.DateOfDeath;

GO;

CREATE OR ALTER VIEW vStoresInventorySummary
AS
	SELECT
		Stores.Name AS [Namn],
		COUNT(StoresInventory.ISBN) AS [Titlar],
		FORMAT(SUM(StoresInventory.Quantity), '0,0 st') AS [Totalt i lager],
		FORMAT(SUM(StoresInventory.Quantity * Books.Price), '0,0.00:-') AS [Lagervärde (SEK)]
	FROM Stores
		LEFT JOIN StoresInventory ON StoresInventory.StoreID = Stores.ID
		LEFT JOIN Books ON StoresInventory.ISBN = Books.ISBN13
	GROUP BY Stores.ID, Stores.Name;

GO;

CREATE OR ALTER VIEW vStoresInventoryDetails
AS
	SELECT
		Stores.ID AS [Butik ID],
		Stores.Name AS [Butik],
		Books.Title AS [Titel],
		FORMAT(StoresInventory.Quantity, '0,0 st') AS [Antal i lager],
		FORMAT(Books.Price, '0,0.00:-') AS [Pris (SEK)],
		FORMAT(StoresInventory.Quantity * Books.Price, '0,0.00:-') AS [Lagervärde (SEK)]
	FROM Stores
		LEFT JOIN StoresInventory ON StoresInventory.StoreID = Stores.ID
		LEFT JOIN Books ON StoresInventory.ISBN = Books.ISBN13
	GROUP BY Stores.ID, Stores.Name, StoresInventory.Quantity, Books.Title, Books.Price;

GO;

CREATE OR ALTER VIEW vBookSummary
AS
	SELECT
		Books.Title AS [Titel],
		BookGenres.Genre AS [Genre],
		CASE
        WHEN AVG(Reviews.Rating * 1.0) IS NULL
		THEN '-'
        ELSE FORMAT(AVG(Reviews.Rating * 1.0), '0.0')
    END AS [Betyg],
		Books.Format AS [Format],
		Books.Dimensions AS [Dimensioner],
		FORMAT(Books.Weight, '0g') AS [Vikt],
		FORMAT(Books.Price, '0,0.00:-') AS [Pris (SEK)],
		BookPublishers.Publisher AS [Förlag],
		Books.ReleaseDate AS [Utgivningsdatum]
	FROM Books
		LEFT JOIN (
    SELECT ISBN, STRING_AGG(Genres.Name, ', ') AS [Genre]
		FROM BookGenres
			JOIN Genres ON Genres.ID = BookGenres.GenreID
		GROUP BY ISBN
) AS BookGenres ON BookGenres.ISBN = Books.ISBN13
		LEFT JOIN (
    SELECT ISBN, STRING_AGG(Publishers.Name, ', ') AS [Publisher]
		FROM BookPublishers
			JOIN Publishers ON Publishers.ID = BookPublishers.PublisherID
		GROUP BY ISBN
) AS BookPublishers ON BookPublishers.ISBN = Books.ISBN13
		LEFT JOIN BookReviews ON BookReviews.ISBN = Books.ISBN13
		LEFT JOIN Reviews ON Reviews.ID = BookReviews.ReviewID
	GROUP BY Books.Title, Books.Format, Books.Dimensions, Books.Weight, Books.Price, Books.ReleaseDate, BookGenres.Genre, BookPublishers.Publisher;

GO;

CREATE OR ALTER VIEW vBookReviews
AS
	SELECT
		Books.Title AS [Bok],
		Reviews.Rating AS [Betyg],
		Reviews.Text AS [Recension],
		CONCAT(Customers.FirstName, ' ', Customers.LastName) AS [Användare],
		FORMAT(Reviews.DateSubmitted, 'HH:mm - d MMMM yyyy', 'sv') AS [Datum]
	FROM Books
		JOIN BookReviews on BookReviews.ISBN = Books.ISBN13
		JOIN Reviews ON Reviews.ID = BookReviews.ReviewID
		JOIN Customers ON Customers.ID = Reviews.CustomerID;

GO;

-- Stored Procedures ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE spMoveBook
	@FromStoreID INT,
	@ToStoreID INT,
	@ISBN NVARCHAR(13),
	@MoveQuantity INT = 1
AS
BEGIN
	IF ((SELECT Quantity
	FROM StoresInventory
	WHERE StoreID = @FromStoreID AND ISBN = @ISBN) >= @MoveQuantity)
	BEGIN
		IF ((SELECT Quantity
		FROM StoresInventory
		WHERE StoreID = @FromStoreID AND ISBN = @ISBN) = @MoveQuantity)
		DELETE FROM StoresInventory
		WHERE StoreID = @FromStoreID AND ISBN = @ISBN;
	ELSE
		UPDATE StoresInventory
		SET Quantity -= @MoveQuantity
		WHERE StoreID = @FromStoreID AND ISBN = @ISBN;

		IF EXISTS (SELECT *
		FROM StoresInventory
		WHERE StoreID = @ToStoreID AND ISBN = @ISBN)
		UPDATE StoresInventory
		SET Quantity += @MoveQuantity
		WHERE StoreID = @ToStoreID AND ISBN = @ISBN;
	ELSE
		INSERT INTO StoresInventory
		VALUES(@ToStoreID, @ISBN, @MoveQuantity);
	END
ELSE
	PRINT 'Inte tillräckligt med böcker på lager!';
END;

-- Populate Tables ------------------------------------------------------------------------------
INSERT INTO Authors
	(ID, FirstName, LastName, DateOfBirth, DateOfDeath)
VALUES
	(1, 'Astrid', 'Lindgren', '1907-11-14', '2002-01-28'),
	(2, 'William', 'Shakespeare', '1564-04-23', '1616-04-23'),
	(3, 'Neil', 'Gaiman', '1960-11-10', NULL),
	(4, 'J. R. R.', 'Tolkien', '1892-01-03', '1973-09-02');

INSERT INTO Books
	(ISBN13, Title, Language, Price, ReleaseDate, Pages, Edition, Format, Dimensions, Weight)
VALUES
	-- Astrid Lindgren
	('9789129739053', 'Mio, min Mio', 'Svenska', 149.99, '2022-10-21', 148, 16, 'Inbunden (Klotband)', '280 x 200 x 20 mm', 835),
	('9789129657869', 'Madicken', 'Svenska', 155.25, '2004-02-01', 184, 12, 'Inbunden', '220 x 165 x 15 mm', 410),
	('9789129657982', 'Bröderna Lejonhjärta', 'Svenska', 199.00, '2004-03-01', 256, 9, 'Inbunden (Halvklotband)', '215 x 160 x 20 mm', 520),
	('9789129683844', 'Ronja Rövardotter', 'Svenska', 79.99, '2012-08-01', 193, 1, 'Pocket', '180 x 110 x 10 mm', 110),
	-- J.R.R. Tolkien
	('9780261102354', 'Fellowship Of The Ring', 'Engelska', 132.00, '1991-01-01', 544, NULL, 'Häftad (Paperback)', '180 x 110 x 38 mm', 295),
	('9780261102361', 'The Two Towers', 'Engelska', 125.00, '1991-07-01', 464, NULL, 'Häftad (Paperback)', '180 x 115 x 30 mm', 250),
	('9780007203567', 'The Return of the King', 'Engelska', 269.50, '2005-10-01', 464, NULL, 'Inbunden (Hardback)', '230 x 150 x 26 mm', 680),
	-- William Shakespeare
	('9789170370120', 'Macbeth', 'Svenska', 79.99, '2003-06-01', 96, 1, 'Pocket', '181 x 100 x 9 mm', 55),
	('9789170379673', 'Hamlet', 'Svenska', 39.99, '2003-04-01', 139, 1, 'Pocket', '176 x 100 x 10 mm', 80),
	-- Neil Gaiman
	('9781472260222', 'The Ocean at the End of the Lane', 'Engelska', 146.50, '2020-11-12', 336, NULL, 'Häftad (Paperback / softback)', '198 x 130 x 24 mm', 360);

INSERT INTO Stores
	(ID, Name, Address, PostalCode, City)
VALUES
	(1, 'Adlibris', 'Kungsgatan 34 (hörnet Magasinsgatan/Kungsgatan)', '411 19', 'Göteborg'),
	(2, 'Pocket Shop', 'Kungsportsplatsen 1', '411 10', 'Göteborg'),
	(3, 'Akademibokhandeln', 'Norra Hamngatan 26, Nordstan', '411 06', 'Göteborg');

INSERT INTO StoresInventory
	(StoreID, ISBN, Quantity)
VALUES
	-- ID 1 = Adlibris
	(1, '9789129739053', FLOOR(RAND() * 1000)),
	(1, '9789129657869', FLOOR(RAND() * 1000)),
	(1, '9789129657982', FLOOR(RAND() * 1000)),
	(1, '9789129683844', FLOOR(RAND() * 1000)),
	(1, '9780261102354', FLOOR(RAND() * 1000)),
	(1, '9780261102361', FLOOR(RAND() * 1000)),
	(1, '9780007203567', FLOOR(RAND() * 1000)),
	(1, '9789170370120', FLOOR(RAND() * 1000)),
	(1, '9789170379673', FLOOR(RAND() * 1000)),
	(1, '9781472260222', FLOOR(RAND() * 1000)),
	-- ID 2 = Pocket Shop
	(2, '9789170370120', FLOOR(RAND() * 1000)),
	(2, '9789170379673', FLOOR(RAND() * 1000)),
	(2, '9789129683844', FLOOR(RAND() * 1000)),
	-- ID 3 = Akademibokhandeln
	(3, '9789170379673', FLOOR(RAND() * 1000)),
	(3, '9780261102354', FLOOR(RAND() * 1000)),
	(3, '9780007203567', FLOOR(RAND() * 1000)),
	(3, '9789170370120', FLOOR(RAND() * 1000)),
	(3, '9780261102361', FLOOR(RAND() * 1000));

INSERT INTO BookAuthors
	(ISBN, AuthorID)
VALUES
	-- Astrid Lindgren
	('9789129739053', 1),
	('9789129657869', 1),
	('9789129657982', 1),
	('9789129683844', 1),
	-- J.R.R. Tolkien
	('9780261102354', 4),
	('9780261102361', 4),
	('9780007203567', 4),
	-- William Shakespeare
	('9789170370120', 2),
	('9789170379673', 2),
	-- Neil Gaiman
	('9781472260222', 3);

INSERT INTO Genres
	([ID], [Name], [Description])
VALUES
	(1, 'Fantasy', 'Genre involving elements of magic, supernatural phenomena, or mythical creatures, often set in imaginary worlds.'),
	(2, 'Science Fiction', 'Fictional works based on speculative scientific developments, futuristic technology, space exploration, etc.'),
	(3, 'Mystery', 'Involves solving a crime, puzzling event, or enigmatic situation, often with unexpected twists.'),
	(4, 'Romance', 'Focuses on love and emotional relationships between characters, typically with a happy ending.'),
	(5, 'Thriller', 'Exciting and suspenseful stories characterized by fast-paced action, danger, and thrilling plot twists.'),
	(6, 'Horror', 'Intended to evoke fear, dread, or terror in the audience, often involving supernatural or macabre elements.'),
	(7, 'Adventure', 'Stories featuring exciting journeys, exploration, or risky undertakings in various settings.'),
	(8, 'Biography', 'Depiction of a persons life story, typically written by someone else.'),
	(9, 'Autobiography', 'A persons own account of their life, experiences, and events they have witnessed or participated in.'),
	(10, 'Non-fiction', 'Factual literature based on real events, people, or information.'),
	(11, 'Self-Help', 'Books aiming to assist readers in solving personal problems or improving aspects of their lives.'),
	(12, 'Comedy', 'Intended to amuse and entertain, often characterized by humor, wit, and light-heartedness.'),
	(13, 'Drama', 'Centered around serious, emotional, or intense situations, often exploring human conflict and emotions.'),
	(14, 'Action', 'Fast-paced stories with high energy, featuring physical feats, combat, or adventurous activities.'),
	(15, 'Crime', 'Involves criminal activities, investigations, or legal procedures, focusing on criminal motives and detection.'),
	(16, 'Childrens', 'Specifically aimed at a younger audience, featuring stories suitable for childrens reading levels and interests.'),
	(17, 'Historical Fiction', 'Set in the past and often incorporates real historical events, figures, or settings into fictional narratives.');

INSERT INTO BookGenres
	(ISBN, GenreID)
VALUES
	-- Astrid Lindgren
	('9789129739053', 16),
	('9789129657869', 16),
	('9789129657982', 16),
	('9789129657982', 6),
	('9789129683844', 16),
	-- J.R.R. Tolkien
	('9780261102354', 1),
	('9780261102354', 7),
	('9780261102361', 1),
	('9780261102361', 7),
	('9780007203567', 1),
	('9780007203567', 7),
	-- William Shakespeare
	('9789170370120', 3),
	('9789170379673', 3),
	-- Neil Gaiman
	('9781472260222', 7);

INSERT INTO Customers
	(ID, FirstName, LastName, Email, Address, Phone)
VALUES
	(1, 'Hitte', 'Påsson', 'e@mail', 'Adress1', '0707123456'),
	(2, 'Näj', 'Sson', 'eeee@mail', 'Adress2', '0707654321'),
	(3, 'Pffff', 'von Bark', 'mail@e', 'Adress3', '0707963852');

INSERT INTO Reviews
	(ID, CustomerID, Text, Rating, DateSubmitted)
VALUES
	(1, 1, 'Kort sagt bara läs! Läs den och njut! En av mina favoritböcker i min favoritserie. Språket, miljön, karaktärerna, ja allt!', 5, GETDATE()),
	(2, 3, 'Madicken-boken med de två mest kända berättelserna. Det är här som Madicken hoppar från taket med ett paraply och Lisabet pillar in en ärta i näsan. Men det sker även andra små "äventyr" i Junibacken med omnejd som det är kul att läsa om. Madicken är en av Astrids "romantiserade realism"-böcker, i stil med Bullerbyn och Emil i Lönneberga. Och just Emil finns det ett tydligt släktskap med: Båda har en liknande familjesituation, lever i Småland i 1900-talets början och båda två är härligt finurliga, påhittiga och godhjärtade karaktärer med en tendens att få små galna infall. Och tur är väl det, för det ger oss en hel hoper härliga historier att underhålla oss med. Språket är skrivet på det klassiskt finurliga Lindgren viset och karaktärerna som uppträder i boken är just så sympatiska, charmiga och roliga som är typiskt för Lindgren karaktärer. Ilon Wiklands teckningar förstärker den trevliga stämningen och man blir helt enkelt glad av att läsa den här boken. Läsvärd? Apselut, som Lisabet hade utryckt det.Rekommenderas varmt till alla Astrid älskare, stora som små.', 5, GETDATE()),
	(3, 2, 'Min favorit Neil Gaiman novell + detta alternativa omslag gör detta till ett självklart köp. Rekommenderar verkligen denna boken!', 5, GETDATE()),
	(4, 1, 'En av Shakespears bästa tragedier. bra språk, lätt använd bok som ger hela dramat med tillhörande sceneri, så som det är i originalet. några tveksamma felöversättningar men ändå på det stora hela en väldigt bra bok. Snyggt format och lätt att ta med sig.', 5, GETDATE()),
	(5, 2, 'Text', 1, GETDATE()),
	(6, 2, 'Test', 2, GETDATE()),
	(7, 2, 'estfgse', 4, GETDATE()),
	(8, 2, 'qewtry', 3, GETDATE());

INSERT INTO BookReviews
	(ISBN, ReviewID)
VALUES
	('9780261102354', 1),
	('9789129657869', 2),
	('9781472260222', 3),
	('9789170370120', 4),
	('9789170370120', 5),
	('9781472260222', 6),
	('9789129657869', 7),
	('9780261102354', 8);

INSERT INTO Publishers
	(ID, Name)
VALUES
	(1, 'Rabén & Sjögren'),
	(2, 'Penguin Books'),
	(3, 'Bonnier Books');

INSERT INTO BookPublishers
	(ISBN, PublisherID)
VALUES
	-- Astrid Lindgren
	('9789129739053', 1),
	('9789129657869', 1),
	('9789129657982', 1),
	('9789129683844', 1),
	('9789129657982', 3),
	('9789129683844', 3),
	-- J.R.R. Tolkien
	('9780261102354', 2),
	('9780261102361', 2),
	('9780007203567', 2),
	('9780007203567', 3),
	-- William Shakespeare
	('9789170370120', 3),
	('9789170379673', 3),
	('9789170370120', 2),
	-- Neil Gaiman
	('9781472260222', 3);

-------------------------------------------------------------------------------------------------

SELECT *
FROM Authors;

SELECT *
FROM Books;

SELECT *
FROM Stores;

SELECT *
FROM Genres;

SELECT *
FROM StoresInventory;

SELECT *
FROM BookAuthors;

SELECT *
FROM vTitlesPerAuthor;

SELECT *
FROM vStoresInventorySummary;

SELECT *
FROM vStoresInventoryDetails;

SELECT *
FROM vBookSummary;

SELECT *
FROM vBookReviews;
-- SP
SELECT *
FROM vStoresInventoryDetails;
EXEC spMoveBook @FromStoreID = 1, @ToStoreID = 3, @ISBN = '9789129739053', @MoveQuantity = 1;
SELECT *
FROM vStoresInventoryDetails;
--

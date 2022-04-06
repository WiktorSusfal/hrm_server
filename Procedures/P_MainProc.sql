/****** Object:  StoredProcedure [dbo].[HRM_00_PrepareHtmls]    Script Date: 05.04.2022 18:29:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HRM_00_PrepareHtmls] 

	--ID DLA KODU HTML Z TABELI dbo.Report_HTMLS.
	@htmlID INT
	,@prefixHtmlID INT = NULL
	,@suffixHtmlID INT = NULL

	--NAZWA BAZY DANYCH, SCHEMATU ORAZ FUNKCJI, WIDOKU LUB TABELI Z DANYMI DO PODMIANY W HTML'U.
	,@databaseName NVARCHAR(200) = NULL
	,@schemaName NVARCHAR(200) = NULL
	,@datasourceName NVARCHAR(200) = NULL 

	--TYP ŻRÓDŁA DANYCH (V - WIDOK, T - TABELA, F - FUNKCJA 
	,@datasourceType varchar(1) = NULL

	--NAZWY CHARAKTERYSTYCZNYCH KOLUMN
	,@mAddressColName nvarchar(MAX)	= NULL
	,@mSubjectColName nvarchar(MAX) = NULL

	-- OPCJONALNY CIĄG ZNAKÓW REZPREZENTUJĄCY WARTOŚCI ARGUMENTÓW DLA FUNCKJI - JEŚLI TYPEM ŹRÓDŁA DANYCH JEST 'F'
	-- ARGUMENTY PODANE JAKO JEDEN CIĄG ZNAKÓW. ARGUMENTY W CIĄGU ROZDZIELONE PRZECINKAMI. KAŻDY ARGUMENT TEKSTOWY DODATKOWO OKOLONY POJEDYNCZYMI APOSTROFAMI
	,@fnctArgs nvarchar(MAX) = NULL

	-- SPOSÓB ZWRACANIA HTML. JEŚLI 'Y', TO W PRZYPADKU GDY ŹRÓDŁO DANYCH ZAWIERA WIELE REKORDÓW, ZWRÓCONY ZOSTANIE HTML W POSTACI:
	-- PREFIX_HTML + HTML x (LICZBA REKORDÓW ZE ŻRÓDŁA) + SUFFIX_HTML. 
	-- DLA KAŻDEGO REKORDU ZE ŹRÓDŁA ZOSTANĄ PODMIENIONE PARAMETRY W ODPOWIADAJĄCYM MU KAWAŁKU HTML'A. 

	-- JEŚLI NIE 'Y', TO ZOSTANIE ZWRÓCONYCH TYLE HTMLI W POSTACI: PREFIX_HTML + HTML x 1 + SUFFIX_HTML, ILE REKORDÓW ZAWIERA ŹRÓDŁO.
	,@returnAsOneHtml nvarchar(1) = NULL

	-- NAZWA KOLUMNY, PO KTÓREJ SORTOWANE BĘDĄ REKORDY Z WARTOŚCIAMI PARAMETRÓW - W PRZYPADKU, GDY @returnAsOneHtml = 'Y'.
	,@orderByColumn nvarchar(MAX) = NULL
	
	-- JEŚLI NIE 'NULL', TO ZRODŁO DANYCH ZOSTANIE POGRUPOWANE NA PODŹRÓDŁA WEDŁUG PODANEJ TUTAJ KOLUMNY (JEDNEJ!!!). DO UŻYCIA, GDY @returnAsOneHtml = 'Y'. WTEDY ZWRACANE SĄ HTML'E W POSTACI:
	-- (PREFIX_HTML + HTML x (LICZBA REKORDÓW Z PODGRUPY ŹRÓDŁA) + SUFFIX_HTML) x (LICZBA PODGRUP ŹRÓDŁA)
	,@splitResultSetBy nvarchar(MAX) = NULL

	--PRZEKIEROWANIE WYJŚCIA: M - MAIL, S - SELECT (WYDRUK NA EKRAN)
	,@outputMode NVARCHAR(1) = NULL

	--NAZWA PROFILU E-MAIL NA SERWERZE SQL
	,@mailProfile VARCHAR(100) = NULL

	-- JEŚLI 'Y' - KODY HTML Z WYNIKOWEJ TABELI ZOSTANĄ ZE SOBĄ POŁĄCZONE. ŁĄCZENIE HTML'I ODBYWA SIĘ NA PODSTAWIE ADRESÓW E-MAIL I TEMATÓW.
	-- KAŻDY KOD HTML Z TAKIMI SAMYMI WARTOŚCIAMI TYCH KOLUMN ZOSTANIE POŁĄCZONY W KOLEJNOŚCI ALFABETYCZNEJ.  
	,@mergeOutHTMLs NVARCHAR(1) = NULL

AS
BEGIN

	SET NOCOUNT ON;
	DECLARE 
			@tempQuery NVARCHAR(MAX)
			,@prefixHtml NVARCHAR(MAX)
			,@suffixHtml NVARCHAR(MAX)
			,@srcHtml NVARCHAR(MAX)
			,@resHtml NVARCHAR(MAX)
			,@fullDataSrcName NVARCHAR(MAX)
			,@paramRowCount INT
			,@iter INT = 1
			,@paramName1 VARCHAR(400)
			,@tmpParamValue NVARCHAR(MAX)
			,@tmpSPOutParams NVARCHAR(MAX)
			,@paramPrefix NVARCHAR(10)
			,@paramSuffix NVARCHAR(10)
			,@fullParamName NVARCHAR(500)
			,@mailAddress NVARCHAR(MAX)
			,@mailSubject NVARCHAR(MAX)
			,@noOfGRoups INT = 1
			,@currentGroup INT = 1
			,@currentGroupName NVARCHAR(MAX)
			,@tmpColumnSet NVARCHAR(MAX)
			,@tmpDataSourceName NVARCHAR(MAX)
			,@tmpWhereClause NVARCHAR(MAX)
			,@invokeNo INT
			,@globalTempTableName NVARCHAR(MAX)
			,@noOfParams INT = 0;

	--NAZWY KOLUMN ZCZYTANE ZE ŹRÓDŁA DANYCH
	DECLARE @dataColumns AS TABLE (colName VARCHAR(400));
	--NAZWY PARAMETRÓW UŻYTE W KODZIE HTML Z @htmlID
	DECLARE @params AS TABLE (paramName VARCHAR(400));
	--WARTOŚCI CHARAKTERYSTYCZNE KOLUMNY, PO KTÓREJ GRUPOWANE JEST ŹRÓDŁO WARTOŚCI PARAMETRÓW. 
	DECLARE @distGroupValues AS TABLE (__LP INT, distValue NVARCHAR(MAX));
	--WYNIK PROCEDURY - WYGENEROWANE HTML'E + LISTA Z ADRESAMI DO WYSYŁKI + TEMATY MAILI. 
	DECLARE @resultSet AS TABLE (html NVARCHAR(MAX), mAddress NVARCHAR(MAX), mSubject NVARCHAR(MAX));
	
	SET @srcHtml = (SELECT HTML FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(LEN(@srcHtml), 0) = 0
		RETURN

	-- ODCZYTANIE OPCJONALNYCH PARAMETRÓW PROCEDURY. W RAZIE GDY NIEPODANE, PRÓBY ODCZYTANIA ODPOWIEDNICH Z TABELI dbo.Report_HTMLS
	IF ISNULL(@prefixHtmlID, 0) = 0
		SET @prefixHtmlID = (SELECT prefixHtmlID FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@suffixHtmlID, 0) = 0
		SET @suffixHtmlID = (SELECT suffixHtmlID FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@databaseName, '') = ''
		SET @databaseName = (SELECT databaseName FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@schemaName, '') = ''
		SET @schemaName = (SELECT schemaName FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@datasourceName, '') = ''
		SET @datasourceName = (SELECT datasourceName FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@datasourceType, '') = ''
		SET @datasourceType = (SELECT datasourceType FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@fnctArgs, '') = ''
		SET @fnctArgs = (SELECT fnctArgs FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@returnAsOneHtml, '') = ''
		SET @returnAsOneHtml = (SELECT returnAsOneHtml FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@orderByColumn, '') = ''
		SET @orderByColumn = (SELECT orderByColumn FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@splitResultSetBy, '') = ''
		SET @splitResultSetBy = (SELECT splitResultSetBy FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@mSubjectColName, '') = ''
		SET @mSubjectColName = (SELECT mSubjectColName FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@mAddressColName, '') = ''
		SET @mAddressColName = (SELECT mAddressColName FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@outputMode, '') = ''
		SET @outputMode = (SELECT outputMode FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@mailProfile, '') = ''
		SET @mailProfile = (SELECT mailProfile FROM dbo.Report_HTMLS WHERE ID = @htmlID);
	IF ISNULL(@mergeOutHTMLs, '') = ''
		SET @mergeOutHTMLs = (SELECT mergeOutHTMLs FROM dbo.Report_HTMLS WHERE ID = @htmlID);

	-- PRZYPISANIE WARTOŚCI DOMYŚLNYCH - W RAZIE GDYBY ZARÓWNO DO PROCEDURY, JAK I DO TABELI  dbo.Report_HTMLS PRZEKAZANO NULL'E
	SET @fnctArgs = ISNULL(@fnctArgs, N'');
	SET @returnAsOneHtml = ISNULL(@returnAsOneHtml, N'Y');
	SET @outputMode = ISNULL(@outputMode, N'S');
	SET @mergeOutHTMLs = ISNULL(@mergeOutHTMLs, N'N')

	-- OTOCZENIE NAZW KOLUMN NAWIASAMI '[]'
	SET @mAddressColName = dbo.HRM_00_QuoteIfNotQuoted(@mAddressColName);
	SET @mSubjectColName = dbo.HRM_00_QuoteIfNotQuoted(@mSubjectColName);

	-- ODCZYTANIE ZMIENNYCH, KTÓRE NIE SĄ PRZEKAZYWANE JAKO PARAMETR DO PROCEDURY
	SET @paramPrefix = ISNULL((SELECT StartParamPattern FROM dbo.Report_HTMLS WHERE ID = @htmlID), N'');
	SET @paramSuffix = ISNULL((SELECT EndParamPattern FROM dbo.Report_HTMLS WHERE ID = @htmlID), N'');

	-- ZAKOŃCZ, JEŚLI WYRÓŻNIKI PARAMETRÓW W KODZIE GŁÓWNEGO HTML NIE POKRYWAJĄ SIĘ Z TYMI 
	-- Z PREFIKSA I SUFFIKSA HTML'A
	IF	@paramPrefix != (SELECT StartParamPattern FROM dbo.Report_HTMLS WHERE ID = @prefixHtmlID)
		OR
		@paramPrefix != (SELECT StartParamPattern FROM dbo.Report_HTMLS WHERE ID = @suffixHtmlID)
		OR
		@paramSuffix != (SELECT EndParamPattern FROM dbo.Report_HTMLS WHERE ID = @prefixHtmlID)
		OR
		@paramSuffix != (SELECT EndParamPattern FROM dbo.Report_HTMLS WHERE ID = @suffixHtmlID)
		
		RETURN;


	-- ODCZYT KODU HTML BĘDĄCEGO PREFIKSEM I SUFFIKSEM GŁÓWNEGO HTML'A
	SET @prefixHtml = ISNULL((SELECT HTML FROM dbo.Report_HTMLS WHERE ID = @prefixHtmlID), N'');
	SET @suffixHtml = ISNULL((SELECT HTML FROM dbo.Report_HTMLS WHERE ID = @suffixHtmlID), N'');

	-- ODCZYTANIE NAZW PARAMETRÓW ZAWARTYCH W PREFIXIE, SUFFIXIE ORAZ GŁÓWNYM HTML
	-- ORAZ OTOCZENIE ICH '[]' W CELU ODWOROWANIA NAZW KOLUMN ŹRÓDŁA DANYCH
	INSERT INTO @params SELECT * FROM 
		(SELECT paramName FROM dbo.Report_HTML_Params WHERE reportID = @htmlID
			UNION
		 SELECT paramName FROM dbo.Report_HTML_Params WHERE reportID = @prefixHtmlID
			UNION
		 SELECT paramName FROM dbo.Report_HTML_Params WHERE reportID = @suffixHtmlID
		) P;
	SET @noOfParams = @@ROWCOUNT;
	UPDATE @params SET paramName = dbo.HRM_00_QuoteIfNotQuoted(paramName);

	-- FUNKJCA 'HRM_00_QuoteIfNotQuoted' ZWRÓCI NULL, GDY ARGUMENT JEST NULLEM LUB PUSTYM CIĄGIEM ZNAKÓW
	SELECT	@databaseName		= dbo.HRM_00_QuoteIfNotQuoted(@databaseName)
			,@schemaName		= dbo.HRM_00_QuoteIfNotQuoted(@schemaName)
			,@datasourceName	= dbo.HRM_00_QuoteIfNotQuoted(@datasourceName);
		
	SET @fullDataSrcName = @databaseName + N'.' + @schemaName + N'.' + @datasourceName + 
							CASE WHEN @datasourceType = 'F' THEN N'(' + @fnctArgs + N')' ELSE N'' END

	-- JEŚLI ŹRÓDŁO DANYCH NIE JEST PODANE - ZWRÓĆ SAM HTML BEZ ADRESU I TEMATU MAILA
	-- ŹRÓDŁO JEST KLUCZOWE. JEŚLI JEST ŹRÓDŁO A NIE MA PARAMETRÓW - WYKONAJ PROCEDURĘ BY SPRÓBOWAĆ PRZYPISAĆ ADRES MAILA ORAZ TEMAT. 
	IF @fullDataSrcName IS NULL
		IF ISNULL(@noOfParams, 0) = 0
			SELECT 
				(@prefixHtml + @srcHtml + @suffixHtml) AS [html]
				,'' AS [mAddress]
				,'' AS [mSubject]	
		ELSE
			RETURN;

	-- USTAWIENIE NAZWY DLA NOWEJ TABELI GLOBALNEJ DO PRZECHOWYWANIA WARTOŚCI PARAMETRÓW HTML'I. NAZWY MUSZĄ BYĆ UNIKATOWE W PRZYPADKU KILKU WYWOŁAŃ TEJ PROCEDURY NA RAZ (ABY PROCEDURY NIE NADPISYWAŁY TEJ SAMEJ TABELI JEDNOCZEŚNIE). 
	-- NIEMOŻLIWE JEST UŻYCIE LOKALNYCH TABEL TYMCZASOWYCH, GDYŻ SĄ ONE TUTAJ TWORZONE W WYWOŁANIACH KOMEND (EXEC) I BYŁYBY NATYCHMIAST USUWANE PO SKOŃCZENIU WYWOŁANIA WEWNĄTRZ EXEC. 
	SELECT @invokeNo = NEXT VALUE FOR dbo.HRM_00_InvokeNo;

	SET @globalTempTableName = N'##HtmlParamsDataSource_' + CAST(@invokeNo AS nvarchar);
	IF ISNULL(@globalTempTableName, N'##HtmlParamsDataSource_') = N'##HtmlParamsDataSource_'
		RETURN

	--ODCZYTAJ WSZYSTKIE ORYGINALNE NAZWY KOLUMN ZE ŹRÓDŁA DANYCH
	--DATASOURCE TYPE: V - VIEW, F - TABLE FUNCTION, T - TABLE
	--JEŚLI 'datasourceType' JEST NULL, to 'tempQuery' RÓWNIEŻ BĘDZIE NULL
	SET @tempQuery = dbo.HRM_00_BuildQueryForDSColumnNames(@datasourceType, @databaseName, @datasourceName);
	IF ISNULL(@tempQuery, N'') = N''
		RETURN

	INSERT INTO @dataColumns EXEC(@tempQuery);
	IF ISNULL(@@ROWCOUNT, 0) = 0 
		RETURN
	UPDATE @dataColumns SET colName = dbo.HRM_00_QuoteIfNotQuoted(colName); 

	-- JEŚLI NIE PODANO KOLUMNY, PO KTÓREJ NALEŻY POSORTOWAĆ DANE, USTAW JĄ JAKO PIERWSZĄ KOLUMNĘ ZE ŹRÓDŁA
	IF ISNULL(@orderByColumn, N'') = N''
		SET @orderByColumn = (SELECT TOP 1 colName FROM @dataColumns);
	SET @orderByColumn = dbo.HRM_00_QuoteIfNotQuoted(@orderByColumn);
	
	-- JEŚLI PODANA KOLUMNA, PO KTÓREJ NALEŻY SORTOWAĆ, NIE ZAWIERA SIĘ W ZBIORZE KOLUMN ŻRÓDŁA DANYCH, PRZERWIJ.
	IF @orderByColumn NOT IN (SELECT colName FROM @dataColumns)
		RETURN;

	-- JEŚLI ŹRÓDŁO WARTOŚCI PARAMETRÓW MA ZOSTAĆ POGRUPOWANE, WYODRĘBNIJ WSZYSTKIE MOŻLIWE WARTOŚCI KOLUMNY, 
	-- PO KTÓREJ SIĘ GRUPUJE 
	IF ISNULL(@splitResultSetBy, '') != '' 
	BEGIN
		
		SET @splitResultSetBy = dbo.HRM_00_QuoteIfNotQuoted(@splitResultSetBy);

		-- JEŚLI PODANA KOLUMNA, PO KTÓREJ NALEŻY POGRUPOWAĆ, NIE ZAWIERA SIĘ W ZBIORZE KOLUMN ŻRÓDŁA DANYCH, PRZERWIJ.
		IF @splitResultSetBy NOT IN (SELECT colName FROM @dataColumns)
			RETURN;
		 
		SET @tempQuery = 'SELECT ROW_NUMBER() OVER( ORDER BY C1 ASC) AS __LP, C1 FROM 
								(SELECT DISTINCT CAST(' + @splitResultSetBy + N' AS NVARCHAR) AS C1 FROM  ' + @fullDataSrcName + N' ) T'

		INSERT INTO @distGroupValues EXEC(@tempQuery);

		SET @noOfGRoups = @@ROWCOUNT;
		IF ISNULL(@noOfGroups, 0) = 0
			RETURN
	END

	--DLA WSZYSTKICH PODGRUP WYODRĘBNIONYCH ZE ŹRÓDŁA, WYKONAJ PONIŻSZE. JEŚLI ŻRÓDŁO NIE JEST GRUPOWANE, PĘTLA WYKONA SIĘ RAZ. 
	WHILE @currentGroup <= @noOfGRoups
	BEGIN
		
		SET @iter = 1;

		IF OBJECT_ID(('tempdb..' +  @globalTempTableName)) IS NOT NULL 
			EXEC(N'DROP TABLE ' + @globalTempTableName)
	
		-- PRZEPISANIE DO TYMCZASOWEJ TABELI  @globalTempTableName WSZYSTKICH REKORDÓW ZE ŹRÓDŁA (PODŹRÓDŁA), DODAJĄC NUMER WIERSZA. 
		-- NUMER WIERSZA JEST NIEZBĘDNY BY MÓC ITEROWAĆ PO ZBIORZE REKORDÓW Z DYNAMICZNYMI NAZWAMI KOLUMN O ZMIENNEJ LICZBIE. 
		SET @currentGroupName = (SELECT TOP 1 distValue FROM @distGroupValues WHERE __LP = @currentGroup);
		SET @tmpColumnSet = N'ROW_NUMBER() OVER( ORDER BY ' + @orderByColumn + ' ASC) AS __LP, *';

		 -- JEŚLI @splitResultSetBy lub @currentGroupName JEST NULL'EM, TO CAŁE PONIŻSZE WYRAŻENIE BĘDZIE NULL'EM. 
		 --PRZEKAZANE WTEDY JAKO PARAMETR DO FUNKCJI BUDUJĄCEJ ZAPYTANIE 'SELECT', NIE SPOWODUJE ZWRÓCENIA KLAUZULI 'WHERE'.
		SET @tmpWhereClause = N'CAST(' + @splitResultSetBy + N' AS NVARCHAR) = N''' + @currentGroupName + '''';
		SET @tempQuery = dbo.HRM_00_BuildSelectStatement(@tmpColumnSet, @fullDataSrcName, NULL, NULL, NULL, NULL, @globalTempTableName, @tmpWhereClause,  NULL, NULL, NULL);

		EXEC(@tempQuery)
		SET @paramRowCount = @@ROWCOUNT;
				
		IF OBJECT_ID(('tempdb..' + @globalTempTableName)) IS NULL OR ISNULL(@paramRowCount, 0) = 0
		BEGIN
			SET @currentGroup += 1;
			CONTINUE
		END
		
		--JEŚLI MA ZOSTAĆ ZWRÓCONY JEDEN HTML DLA WSZYSTKICH REKORDÓW ŹRÓDŁA (PODŹRÓDŁA), DODAJ PREFIX TERAZ, A W PONIŻSZEJ PĘTLI DODAWAJ KOLEJNE IDENTYCZNE KAWAŁKI HTML'A.
		IF @returnAsOneHtml = 'Y'
			SET @resHtml = @prefixHtml;
	
		WHILE @iter <= @paramRowCount
		BEGIN

			--JEŚLI ZWRACANY JEDEN HTML, DODAJ DO NIEGO KOLEJNY KAWAŁEK. JEŚLI ZWRACANE OSOBNE HTML'E, ZŁÓŻ NOWY Z PREFIXA I TREŚCI WŁAŚCIWEJ
			IF @returnAsOneHtml = 'Y'
			BEGIN
				SET @resHtml += @srcHtml; 
				IF @iter = @paramRowCount
					SET @resHtml += @suffixHtml; 
			END
			ELSE
				SET @resHtml =  @prefixHtml + @srcHtml + @suffixHtml; 

			--DLA KAŻDEGO PARAMETRU ZAWARTEGO W GŁÓWNYM HTML'U, SPRÓBUJ WYDOBYĆ JEGO WARTOŚĆ Z OBECNEGO REKORDU ŹRÓDŁA DANYCH I PODMIENIĆ. 
			DECLARE colCursor CURSOR 
			FOR SELECT paramName FROM @params
			OPEN colCursor
			FETCH NEXT FROM colCursor INTO @paramName1 

			WHILE @@FETCH_STATUS = 0 
			BEGIN
				IF LOWER(@paramName1) IN (SELECT LOWER(colName) FROM @dataColumns)
				BEGIN

					SET @tempQuery = 'SELECT @resultParam = CAST(' + @paramName1 + N' AS NVARCHAR(MAX)) FROM ' +  @globalTempTableName + ' WHERE __LP = ' + CAST(@iter AS NVARCHAR)
					SET @tmpSPOutParams = '@resultParam NVARCHAR(MAX) OUTPUT'

					EXEC sp_executeSQL @tempQuery, @tmpSPOutParams, @resultParam =  @tmpParamValue OUTPUT
					IF @tmpParamValue IS NOT NULL
					BEGIN
						SET @fullParamName = @paramPrefix + dbo.HRM_00_UnQuoteIfQuoted(@paramName1) + @paramSuffix;
						SET @resHtml = REPLACE(@resHtml, @fullParamName, @tmpParamValue);
					END
				END
			
				FETCH NEXT FROM colCursor INTO @paramName1 
			END
			
			CLOSE colCursor
			DEALLOCATE colCursor

			--JEŚLI PODANA KOLUMNA Z ADRESEM E-MAIL ORAZ TEMATEM MAILA ISTNIEJE W ŹRÓDLE DANYCH, PRZYPISZ ADRES I TEMAT DO ZMIENNYCH.
			IF LOWER(@mAddressColName) IN (SELECT LOWER(colName) FROM @dataColumns) AND @mAddressColName IS NOT NULL
			BEGIN
					SET @tempQuery = 'SELECT @resultParam = CAST(' + @mAddressColName + N' AS NVARCHAR(MAX)) FROM ' +  @globalTempTableName + ' WHERE __LP = ' + CAST(@iter AS NVARCHAR)
					SET @tmpSPOutParams = '@resultParam NVARCHAR(MAX) OUTPUT'
					
					EXEC sp_executeSQL @tempQuery, @tmpSPOutParams, @resultParam = @mailAddress OUTPUT
					IF @mailAddress IS NULL
						SET @mailAddress = N'Cannot retrieve mail address.'	
			END
			ELSE
					SET @mailAddress = N'No column with specified name.'

			IF LOWER(@mSubjectColName) IN (SELECT LOWER(colName) FROM @dataColumns) AND @mSubjectColName IS NOT NULL
			BEGIN
					SET @tempQuery = 'SELECT @resultParam = CAST(' + @mSubjectColName + N' AS NVARCHAR(MAX)) FROM ' + @globalTempTableName + ' WHERE __LP = ' + CAST(@iter AS NVARCHAR)
					SET @tmpSPOutParams = '@resultParam NVARCHAR(MAX) OUTPUT'

					EXEC sp_executeSQL @tempQuery, @tmpSPOutParams, @resultParam = @mailSubject OUTPUT
					IF @mailSubject IS NULL
						SET @mailSubject = N'Cannot retrieve mail subject.'	
			END
			ELSE
					SET @mailSubject = N'No column with specified name.'
			
			-- JEŚLI MA BYĆ ZWRACANY OSOBNY HTML DLA KAŻDEGO REKORDU ŹRÓDŁA, TO ZAPISZ DO WYNIKOWEJ TABELI NA KONIEC KAŻDEGO OBIEGU PĘTLI
			IF @returnAsOneHtml != 'Y'
				INSERT INTO @resultSet VALUES (@resHtml, @mailAddress, @mailSubject);
	
			SET @iter = @iter + 1;

		END 

		-- JEŚLI ZWRACANY JEDEN HTML DLA WSZYSTKICH REKORDÓW ŹRÓDŁA (PODŹRÓDŁA), TO ZAPISZ DO WYNIKOWEJ TABELI JEDEN RAZ, POZA PĘTLĄ
		IF @returnAsOneHtml = 'Y'
			INSERT INTO @resultSet VALUES (@resHtml, @mailAddress, @mailSubject);

		SET @currentGroup += 1;
	END

	-- SKASOWANIE TYMCZASOWEJ TABELI GLOBALNEJ
	IF OBJECT_ID(('tempdb..' +  @globalTempTableName)) IS NOT NULL 
		EXEC(N'DROP TABLE ' + @globalTempTableName)

	-- OPCJONALNE ŁĄCZENIE WYNIKOWYCH KODÓW HTML - PRZYPORZĄDKOWANIE NA PODSTAWIE ADRESÓW EMAIL I TEMATÓW
	-- KAŻDY KOD HTML Z TAKIMI SAMYMI WARTOŚCIAMI TYCH KOLUMN ZOSTANIE POŁĄCZONY W KOLEJNOŚCI ALFABETYCZNEJ.  
	IF @mergeOutHTMLs = 'Y'
	BEGIN
		DECLARE @dmAddress NVARCHAR(MAX), @dmSubject NVARCHAR(MAX), @mergedHTML NVARCHAR(MAX) = N''

		DECLARE mCR CURSOR FOR
		SELECT DISTINCT mAddress, mSubject FROM @resultSet

		OPEN mCR 
		FETCH NEXT FROM mCR INTO @dmAddress, @dmSubject

		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			SELECT @mergedHTML += html FROM @resultSet WHERE mAddress = @dmAddress AND mSubject = @dmSubject ORDER BY html
			DELETE FROM @resultSet WHERE mAddress = @dmAddress AND mSubject = @dmSubject
			INSERT INTO @resultSet (html, mAddress, mSubject) VALUES (@mergedHTML, @dmAddress, @dmSubject)
			
			SET @mergedHTML = N''
			FETCH NEXT FROM mCR INTO @dmAddress, @dmSubject
		END

		CLOSE mCR
		DEALLOCATE mCR

	END

	-- ZWRÓCENIE WYNIKU LUB WYSŁANIE MAILI
	IF @outputMode = N'S'
		SELECT * FROM @resultSet;
	ELSE IF @outputMode = N'M'
	BEGIN

		IF ISNULL(@mailProfile, '') = ''
			RETURN

		DECLARE mM CURSOR
		FOR SELECT html, mAddress, mSubject FROM @resultSet;

		OPEN mM;
		FETCH NEXT FROM mM INTO @resHtml, @mailAddress, @mailSubject;

		WHILE @@FETCH_STATUS = 0
		BEGIN
				EXEC msdb.dbo.sp_send_dbmail
					@profile_name = @mailProfile,  
					@recipients = @mailAddress,  
					@body = @resHtml, 
					@body_format ='HTML',
					@subject = @mailSubject;  

			FETCH NEXT FROM mM INTO @resHtml, @mailAddress, @mailSubject;
		END

		CLOSE mM;
		DEALLOCATE mM;

	END


END

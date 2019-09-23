-------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdReemplazaSecuenciaDeEspacios') IS NOT NULL
   DROP FUNCTION dbo.fCfdReemplazaSecuenciaDeEspacios
GO

create function dbo.fCfdReemplazaSecuenciaDeEspacios(@texto nvarchar(max), @repeticiones smallint)
returns NVARCHAR(MAX)
--Propósito. Reemplaza toda secuencia de espacios en un texto por un único espacio
--10/05/12 jcf Creación (Michael Meierruth)
--
begin
	RETURN   replace(replace(replace(replace(replace(replace(replace(ltrim(rtrim(@texto)),
	  '                                 ',' '),
	  '                 ',' '),
	  '         ',' '),
	  '     ',' '),
	  '   ',' '),
	  '  ',' '),
	  '  ',' ')

--Jeff Moden
--REPLACE(
--            REPLACE(
--                REPLACE(
--                    LTRIM(RTRIM(@texto))
--                ,'  ',' '+CHAR(8))  --Changes 2 spaces to the OX model
--            ,CHAR(8)+' ','')        --Changes the XO model to nothing
--        ,CHAR(8),'') AS CleanString --Changes the remaining X's to nothing

end
go
IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdReemplazaSecuenciaDeEspacios()'
ELSE PRINT 'Error en la creación de: fCfdReemplazaSecuenciaDeEspacios()'
GO
-------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdReemplazaCaracteresNI') IS NOT NULL
   DROP FUNCTION dbo.fCfdReemplazaCaracteresNI
GO

create function dbo.fCfdReemplazaCaracteresNI(@texto nvarchar(max))
returns NVARCHAR(MAX)
--Propósito. Reemplaza caracteres no imprimibles por espacios
--26/10/10 jcf Creación
--23/09/19 jcf Agrega '’'
--
as
begin
	declare @textoModificado nvarchar(max)
	select @textoModificado = @texto
	select @textoModificado = replace(@textoModificado, char(13), ' ')
	select @textoModificado = replace(@textoModificado, char(10), ' ')
	select @textoModificado = replace(@textoModificado, char(9), ' ')
	select @textoModificado = replace(@textoModificado, '|', '')
	select @textoModificado = replace(@textoModificado, '’', '''')
	return @textoModificado 
end
go
IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdReemplazaCaracteresNI()'
ELSE PRINT 'Error en la creación de: fCfdReemplazaCaracteresNI()'
GO
---------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdObtienePorcentajeImpuesto') IS NOT NULL
   DROP FUNCTION dbo.fCfdObtienePorcentajeImpuesto
GO

create FUNCTION dbo.fCfdObtienePorcentajeImpuesto (@p_idimpuesto varchar(20))
RETURNS numeric(19,2)
AS
BEGIN
   DECLARE @l_TXDTLPCT numeric(19,5)
   select @l_TXDTLPCT = TXDTLPCT from tx00201 where taxdtlid = @p_idimpuesto
   RETURN(@l_TXDTLPCT)
END
go

IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdObtienePorcentajeImpuesto()'
ELSE PRINT 'Error en la creación de: fCfdObtienePorcentajeImpuesto()'
GO
-------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdReemplazaEspecialesXml') IS NOT NULL
   DROP FUNCTION dbo.fCfdReemplazaEspecialesXml
GO

create function dbo.fCfdReemplazaEspecialesXml(@texto nvarchar(max))
returns NVARCHAR(MAX)
--Propósito. Reemplaza caracteres especiales xml por caracteres ascii. 
--			Al convertir una cadena usando for xml, automáticamente convierte los caracteres especiales. Por eso se deben volver a convertir a ascii.
--26/10/10 jcf Creación
--
as
begin
	declare @textoModificado nvarchar(max)
	select @textoModificado = @texto
	select @textoModificado = replace(@textoModificado, '&amp;', '&')
	select @textoModificado = replace(@textoModificado, '&lt;', '<')
	select @textoModificado = replace(@textoModificado, '&gt;', '>')
	select @textoModificado = replace(@textoModificado, '&quot;', '"')
	select @textoModificado = replace(@textoModificado, '&#39;', '?')
	--select @textoModificado = replace(@textoModificado, '''', '&apos;')
	
	return @textoModificado 
end
go
IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdReemplazaEspecialesXml()'
ELSE PRINT 'Error en la creación de: fCfdReemplazaEspecialesXml()'
GO
-------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdEsVacio') IS NOT NULL
   DROP FUNCTION dbo.fCfdEsVacio
GO

create function dbo.fCfdEsVacio(@texto nvarchar(max))
returns NVARCHAR(MAX)
--Propósito. Devuelve un caracter si el texto es vacío 
--10/03/11 jcf Creación
--
as
begin
	if @texto = ''
		return '-'

	return @texto
end
go
IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdEsVacio()'
ELSE PRINT 'Error en la creación de: fCfdEsVacio()'
GO
--------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiObtieneSegmento2') IS NOT NULL
   DROP FUNCTION dbo.fCfdiObtieneSegmento2
GO

create function dbo.fCfdiObtieneSegmento2(@sopnumbe varchar(21), @separador char(1))
returns table
--Propósito. Obtiene el segundo segmento de una cadena separada por @separador y la convierte a entero
--05/12/17 jcf Creación 
--
	return
			select CONVERT( INT, 
				case when ISNUMERIC(replace(right(@sopnumbe, len(@sopnumbe)-patindex('%'+@separador+'%', @sopnumbe)), '.', '')) = 1 then
									replace(right(@sopnumbe, len(@sopnumbe)-patindex('%'+@separador+'%', @sopnumbe)), '.', '')
					when  ISNUMERIC(replace(right(@sopnumbe, len(@sopnumbe)-patindex('% %', @sopnumbe)), '.', '')) = 1 then				--separador espacio
									replace(right(@sopnumbe, len(@sopnumbe)-patindex('% %', @sopnumbe)), '.', '')
				else 0
				end
				) segmento2

go
IF (@@Error = 0) PRINT 'Creación exitosa de: fCfdiObtieneSegmento2()'
ELSE PRINT 'Error en la creación de: fCfdiObtieneSegmento2()'
GO
-------------------------------------------------------------------------------------------------------

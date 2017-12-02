IF not EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = OBJECT_ID(N'dbo.cfdiCatalogo') AND OBJECTPROPERTY(id,N'IsTable') = 1)
begin
	create table dbo.cfdiCatalogo
	(
	tipo		varchar(5) NOT NULL default 'NA',
	clave		varchar(10) NOT NULL default '',
	descripcion varchar(150) NOT NULL default '',
	CONSTRAINT pkCfdiCatalogo primary key nonclustered
	(tipo, clave) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) on [PRIMARY];
end
else
begin
	ALTER TABLE dbo.cfdiCatalogo DROP CONSTRAINT pkCfdiCatalogo;
	alter table dbo.cfdiCatalogo alter column clave varchar(10) not null;
	ALTER TABLE dbo.cfdiCatalogo ADD CONSTRAINT pkCfdiCatalogo PRIMARY KEY (tipo, clave);
end
go

------------------------------------------------------------------------------------

IF OBJECT_ID ('dbo.fCfdiCatalogoGetDescripcion') IS NOT NULL
   DROP FUNCTION dbo.fCfdiCatalogoGetDescripcion
GO

create function dbo.fCfdiCatalogoGetDescripcion(@tipo varchar(5), @clave varchar(10))
returns table 
as
--Prop�sito. Obtiene la descripci�n de los c�digos del cat�logo
--21/11/17 jcf Creaci�n cfdi 3.3
--
return(
	select descripcion
	from dbo.cfdiCatalogo ct
    where ct.tipo = @tipo
	and ct.clave = @clave
)

go

IF (@@Error = 0) PRINT 'Creaci�n exitosa de: fCfdiCatalogoGetDescripcion()'
ELSE PRINT 'Error en la creaci�n de: fCfdiCatalogoGetDescripcion()'
GO


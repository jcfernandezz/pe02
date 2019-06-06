--PERU
--Factura Electrónica
--Propósito. Rol que da accesos a objetos de factura electrónica
--Requisitos. Ejecutar en la compañía.
--12/12/17 JCF Creación
--
-----------------------------------------------------------------------------------
--use arg10

IF DATABASE_PRINCIPAL_ID('rol_cfdigital') IS NULL
	create role rol_cfdigital;

--Objetos que usa factura electrónica
grant select, insert, update, delete on cfdLogFacturaXML to rol_cfdigital, dyngrp;
grant execute on proc_cfdLogFacturaXMLLoadByPrimaryKey to rol_cfdigital, dyngrp;
grant execute on proc_cfdLogFacturaXMLLoadAll to rol_cfdigital, dyngrp;
grant execute on proc_cfdLogFacturaXMLUpdate to rol_cfdigital, dyngrp;
grant execute on proc_cfdLogFacturaXMLInsert to rol_cfdigital, dyngrp;
grant execute on proc_cfdLogFacturaXMLDelete to rol_cfdigital, dyngrp;

grant select on dbo.vwCfdiTransaccionesDeVenta to rol_cfdigital, dyngrp;
--grant select on dbo.vwCfdiDocumentosAImprimir to rol_cfdigital, dyngrp;
grant select on dbo.vwCfdIdDocumentos  to rol_cfdigital, dyngrp;
grant select on dbo.vwCfdClienteDireccionesCorreo to rol_cfdigital, dyngrp;
grant select on dbo.vwCfdCartasReclamacionDeuda to rol_cfdigital, dyngrp;
grant select on dbo.vwCfdiListaResumenDiario to rol_cfdigital, dyngrp;
grant select on dbo.fCfdiParametros to rol_cfdigital;
grant select on dbo.fCfdiParametrosTipoLeyenda to rol_cfdigital;

grant select on dbo.vwCfdiConceptos to rol_cfdigital;
grant select on dbo.vwCfdiGeneraDocumentoDeVenta to rol_cfdigital;
grant select on dbo.vwCfdiRelacionados to rol_cfdigital;
grant select on dbo.vwCfdiGeneraResumenDiario to rol_cfdigital;

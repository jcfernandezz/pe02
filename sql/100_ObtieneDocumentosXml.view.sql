--FACTURA ELECTRONICA GP - PERU
--Proyectos:		GETTY
--Propósito:		Genera funciones y vistas de FACTURAS para la facturación electrónica en GP - PERU
--Referencia:		
--		05/12/17 Versión CFDI UBL 2.0
--Utilizado por:	Aplicación C# de generación de factura electrónica PERU
-------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiCertificadoVigente') IS NOT NULL
   DROP FUNCTION dbo.fCfdiCertificadoVigente
GO

create function dbo.fCfdiCertificadoVigente(@fecha datetime)
returns table
as
--Propósito. Verifica que la fecha corresponde a un certificado vigente y activo
--			Si existe más de uno o ninguno, devuelve el estado: inconsistente
--			También devuelve datos del folio y certificado asociado.
--Requisitos. Los estados posibles para generar o no archivos xml son: no emitido, inconsistente
--06/11/17 jcf Creación cfdi Perú
--
return
(  
	--declare @fecha datetime
	--select @fecha = '1/4/12'
	select top 1 --fyc.noAprobacion, fyc.anoAprobacion, 
			fyc.ID_Certificado, fyc.ruta_certificado, fyc.ruta_clave, fyc.contrasenia_clave, fyc.fila, 
			case when fyc.fila > 1 then 'inconsistente' else 'no emitido' end estado
	from (
		SELECT top 2 rtrim(B.ID_Certificado) ID_Certificado, rtrim(B.ruta_certificado) ruta_certificado, rtrim(B.ruta_clave) ruta_clave, 
				rtrim(B.contrasenia_clave) contrasenia_clave, row_number() over (order by B.ID_Certificado) fila
		FROM cfd_CER00100 B
		WHERE B.estado = '1'
			and B.id_certificado <> 'PAC'	--El id PAC está reservado para el PAC
			and datediff(day, B.fecha_vig_desde, @fecha) >= 0
			and datediff(day, B.fecha_vig_hasta, @fecha) <= 0
		) fyc
	order by fyc.fila desc
)
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiCertificadoVigente()'
ELSE PRINT 'Error en la creación de la función: fCfdiCertificadoVigente()'
GO

--------------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiCertificadoPAC') IS NOT NULL
   DROP FUNCTION dbo.fCfdiCertificadoPAC
GO

create function dbo.fCfdiCertificadoPAC(@fecha datetime)
returns table
as
--Propósito. Obtiene el certificado del PAC. 
--			Verifica que la fecha corresponde a un certificado vigente y activo
--Requisitos. El id PAC está reservado para registrar el certificado del PAC. 
--06/11/17 jcf Creación 
--
return
(  
	--declare @fecha datetime
	--select @fecha = '5/4/12'
	SELECT rtrim(B.ID_Certificado) ID_Certificado, rtrim(B.ruta_certificado) ruta_certificado, rtrim(B.ruta_clave) ruta_clave, 
			rtrim(B.contrasenia_clave) contrasenia_clave
	FROM cfd_CER00100 B
	WHERE B.estado = '1'
		and B.id_certificado = 'PAC'	--El id PAC está reservado para el PAC
		and datediff(day, B.fecha_vig_desde, @fecha) >= 0
		and datediff(day, B.fecha_vig_hasta, @fecha) <= 0
)
go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiCertificadoPAC()'
ELSE PRINT 'Error en la creación de la función: fCfdiCertificadoPAC()'
GO

--------------------------------------------------------------------------------------------------------

IF (OBJECT_ID ('dbo.vwCfdiSopLineasTrxVentas', 'V') IS NULL)
   exec('create view dbo.vwCfdiSopLineasTrxVentas as SELECT 1 as t');
go

alter view dbo.vwCfdiSopLineasTrxVentas as
--Propósito. Obtiene todas las líneas de facturas de venta SOP
--			Incluye descuentos
--Requisito. Atención ! DEBE usar unidades de medida listadas en el SERVICIO DE IMPUESTOS. 
--30/11/17 JCF Creación cfdi 3.3
--
select dt.soptype, dt.sopnumbe, dt.LNITMSEQ, dt.ITEMNMBR, dt.ShipToName,
	dt.QUANTITY, dt.UOFM,
	um.UOFMLONGDESC UOFMsat,
	udmfa.descripcion UOFMsat_descripcion,
	um.UOFMLONGDESC, 
	dt.ITEMDESC,
	dt.ORUNTPRC, dt.OXTNDPRC, dt.CMPNTSEQ, 
	dt.QUANTITY * dt.ORUNTPRC cantidadPorPrecioOri, 
	isnull(ma.ITMTRKOP, 1) ITMTRKOP,		--3 lote, 2 serie, 1 nada
	ma.uscatvls_6, 
	dt.ormrkdam,
	dt.QUANTITY * dt.ormrkdam descuento
from SOP30300 dt
left join iv00101 ma				--iv_itm_mstr
	on ma.ITEMNMBR = dt.ITEMNMBR
outer apply dbo.fCfdiUofM(ma.UOMSCHDL, dt.UOFM ) um
outer apply dbo.fCfdiCatalogoGetDescripcion('UDM', um.UOFMLONGDESC) udmfa

go	

IF (@@Error = 0) PRINT 'Creación exitosa de: vwCfdiSopLineasTrxVentas'
ELSE PRINT 'Error en la creación de: vwCfdiSopLineasTrxVentas'
GO
----------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiImpuestosSop') IS NOT NULL
   DROP FUNCTION dbo.fCfdiImpuestosSop
GO

create function dbo.fCfdiImpuestosSop(@SOPNUMBE char(21), @DOCTYPE smallint, @LNITMSEQ int, @prefijo varchar(15), @tipoPrecio varchar(10))
returns table
as
--Propósito. Detalle de impuestos en trabajo e históricos de SOP. Filtra los impuestos requeridos por @prefijo
--Requisitos. Los impuestos iva deben ser configurados con un prefijo constante
--27/11/17 jcf Creación 
--13/08/18 jcf Agrega txdtlbse
--
return
(
	select imp.soptype, imp.sopnumbe, imp.taxdtlid, imp.staxamnt, imp.orslstax, imp.tdttxsls, imp.ortxsls,
			tx.NAME, tx.cntcprsn, tx.TXDTLPCT, tx.txdtlbse
	from sop10105 imp
		inner join tx00201 tx
		on tx.taxdtlid = imp.taxdtlid
		and tx.cntcprsn like @tipoPrecio
	where imp.sopnumbe = @SOPNUMBE
	and imp.soptype = @DOCTYPE
	and imp.LNITMSEQ = @LNITMSEQ
	and imp.taxdtlid like @prefijo + '%'
)

go


IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiImpuestosSop()'
ELSE PRINT 'Error en la creación de la función: fCfdiImpuestosSop()'
GO

----------------------------------------------------------------------------------------------------------
--IF (OBJECT_ID ('dbo.vwCfdiImpuestos', 'V') IS NULL)
--   exec('create view dbo.vwCfdiImpuestos as SELECT 1 as t');
--go

--alter view dbo.vwCfdiImpuestos	--(@p_soptype smallint, @p_sopnumbe varchar(21), @p_LNITMSEQ int)
--as
--		select 	
--			imp.ortxsls,
--			tx.NAME,
--			case when tx.TXDTLPCT=0 then 'Exento' else 'Tasa' end TipoFactor, 
--			tx.TXDTLPCT,
--			imp.orslstax
--		from sop10105 imp	--sop_tax_work_hist
--		inner join tx00201 tx
--			on tx.taxdtlid = imp.taxdtlid

--go

--IF (@@Error = 0) PRINT 'Creación exitosa de la función: vwCfdiImpuestos()'
--ELSE PRINT 'Error en la creación de la función: vwCfdiImpuestos()'
--GO

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
IF (OBJECT_ID ('dbo.vwCfdiConceptos', 'V') IS NULL)
   exec('create view dbo.vwCfdiConceptos as SELECT 1 as t');
go

alter view dbo.vwCfdiConceptos --(@p_soptype smallint, @p_sopnumbe varchar(21), @p_subtotal numeric(19,6))
as
--Propósito. Obtiene las líneas de una factura 
--			Elimina carriage returns, line feeds, tabs, secuencias de espacios y caracteres especiales.
--Requisito. Se asume que una línea de factura tiene una línea de impuesto
--27/11/17 jcf Creación cfdi 3.3
--03/04/18 jcf Filtra cantidad!=0
--13/08/18 jcf Agrega caso de igv incluido en el precio
--02/01/19 jcf Modifica itemnmbr. Ingresa código sunat en su lugar. Solicitado por J Chiroque.
--
		select ROW_NUMBER() OVER(ORDER BY Concepto.LNITMSEQ asc) id, 
			Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, '/'+rtrim(Concepto.uscatvls_6)+'/' ITEMNMBR, '' SERLTNUM, 
			Concepto.ITEMDESC, Concepto.CMPNTSEQ, 
			rtrim(Concepto.UOFMsat) udemSunat,
			'' NoIdentificacion,
			dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(Concepto.ITEMDESC))), 10) Descripcion, 

			case when isnull(iva.txdtlbse, 3) = 1 then			--igv incluído
					(Concepto.OXTNDPRC)/Concepto.QUANTITY
				else
					(Concepto.OXTNDPRC + isnull(iva.orslstax, 0.00))/Concepto.QUANTITY 
			end precioUniConIva,								--precioReferencial con igv

			case when isnull(iva.txdtlbse, 3) = 1 then			--igv incluído
					case when isnull(gra.ortxsls, 0) != 0 then 0.00 else (Concepto.OXTNDPRC - isnull(iva.orslstax, 0.00))/Concepto.QUANTITY end 
				else
					case when isnull(gra.ortxsls, 0) != 0 then 0.00 else Concepto.OXTNDPRC/Concepto.QUANTITY end 
			end valorUni,										--valor unitario sin igv

			Concepto.QUANTITY cantidad, 
			--Concepto.ORUNTPRC * Concepto.cantidad valorVenta,	--valor venta bruto
			Concepto.descuento,

			case when isnull(iva.txdtlbse, 3) = 1 then			--igv incluído
					Concepto.OXTNDPRC - isnull(iva.orslstax, 0.00)
				else Concepto.OXTNDPRC
			end importe,										--valor de venta (totalVenta)
			isnull(iva.orslstax, 0.00) orslstax,				--igv

			case when isnull(iva.orslstax, 0) != 0 
				then rtrim(iva.cntcprsn)
				else case when isnull(exe.ortxsls, 0) != 0 
					then rtrim(exe.cntcprsn)
					else case when isnull(xnr.ortxsls, 0) != 0
						then rtrim(xnr.cntcprsn)
						else case when isnull(gra.ortxsls, 0) != 0
							then rtrim(gra.cntcprsn)
							else ''
							end
						end
					end
				end tipoPrecio,
			case when isnull(iva.orslstax, 0) != 0 
				then rtrim(iva.name)
				else case when isnull(exe.ortxsls, 0) != 0 
					then rtrim(exe.name)
					else case when isnull(xnr.ortxsls, 0) != 0
						then rtrim(xnr.name)
						else case when isnull(gra.ortxsls, 0) != 0
							then rtrim(gra.name)
							else ''
							end
						end
					end
				end tipoImpuesto								--tipo de afectación
		from vwCfdiSopLineasTrxVentas Concepto
			outer apply dbo.fLcLvParametros('V_PREFEXONERADO', 'V_PREFEXENTO', 'V_PREFIVA', 'V_GRATIS', 'na', 'na') pr	--Parámetros. prefijo inafectos, prefijo exento, prefijo iva
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param1, '%') xnr --exonerado
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param2, '%') exe --inafecto
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param3, '%') iva --iva
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param4, '%') gra --gratuito
		where Concepto.CMPNTSEQ = 0					--a nivel kit
		and Concepto.QUANTITY != 0
go

IF (@@Error = 0) PRINT 'Creación exitosa de: vwCfdiConceptos()'
ELSE PRINT 'Error en la creación de: vwCfdiConceptos()'
GO
-----------------------------------------------------------------------------------------
IF (OBJECT_ID ('dbo.vwCfdiGeneraDocumentoDeVenta', 'V') IS NULL)
   exec('create view dbo.vwCfdiGeneraDocumentoDeVenta as SELECT 1 as t');
go

alter view dbo.vwCfdiGeneraDocumentoDeVenta
as
--Propósito. Elabora un comprobante xml para factura electrónica cfdi Perú
--Requisitos.  
--27/11/17 jcf Creación cfdi Perú
--27/04/18 jcf Ajusta montos exonerado, inafecto, gratuito
--06/06/18 jcf Agrega montos funcionales (pen)
--13/08/18 jcf Agrega emailTo y formaPago
--
	select convert(varchar(20), tv.dex_row_id) correlativo, 
		tv.soptype,
		tv.sopnumbe,
		cmpr.serie,
		cmpr.numero,
		cmpr.tipo									tipoDocumento,
		emi.emisorTipoDoc, 
		emi.TAXREGTN								emisorNroDoc,
		emi.LOCATNNM								emisorNombre,
		emi.ZIPCODE									emisorUbigeo,
		emi.ADDRESS1								emisorDireccion,
		emi.ADDRESS2								emisorUrbanizacion,
		emi.[STATE]									emisorDepartamento,
		emi.COUNTY									emisorProvincia,
		emi.CITY									emisorDistrito,

		cmpr.nsaif_type_nit							receptorTipoDoc,
		tv.idImpuestoCliente						receptorNroDoc,
		tv.nombreCliente							receptorNombre,
		mail.emailTo,

		rtrim(tv.sopnumbe)							idDocumento,
		convert(datetime, tv.fechahora, 126)		fechaEmision,
		tv.curncyid									moneda,
		cmpr.tipoOperacion,
		tv.descuento,

		tv.ORTDISAM,
		isnull(iva.TXDTLPCT, 0.00)/100				ivaTasa,
		isnull(iva.ortxsls, 0.00)					ivaImponible,
		isnull(iva.orslstax, 0.00)					iva,
		isnull(exe.ortxsls, 0.00)					inafecta,
		isnull(xnr.ortxsls, 0.00)					exonerado,
		isnull(gra.ortxsls, 0.00)					gratuito,
		tv.xchgrate,
		tv.total,

		tv.trdisamt, 
		isnull(iva.tdttxsls, 0.00)					IvaImponiblePen,
		isnull(iva.staxamnt, 0.00)					ivaPen,
		isnull(exe.tdttxsls, 0.00)					inafectaPen,
		isnull(xnr.tdttxsls, 0.00)					exoneradoPen,
		isnull(gra.tdttxsls, 0.00)					gratuitoPen,
		tv.docamnt, 

		case when tv.soptype = 3 and tv.orpmtrvd = tv.total 
			then isnull(pg.FormaPago, '1')
			else '1'	--efectivo
		end											formaPago,

		--Para NC indica la discrepancia. Para Factura indica observaciones.
		left(tv.commntid, 2)						discrepanciaTipo,
		dbo.fCfdReemplazaSecuenciaDeEspacios(rtrim(dbo.fCfdReemplazaCaracteresNI(tv.comment_1)), 10) discrepanciaDesc,
		UPPER(DBO.TII_INVOICE_AMOUNT_LETTERS(tv.total, default)) montoEnLetras,
		tv.estadoContabilizado, tv.docdate
	from dbo.vwCfdiSopTransaccionesVenta tv
		cross join dbo.fCfdiEmisor() emi
		outer apply dbo.fLcLvComprobanteSunat (tv.soptype, tv.sopnumbe)  cmpr
		outer apply dbo.fLcLvParametros('V_PREFEXONERADO', 'V_PREFEXENTO', 'V_PREFIVA', 'V_GRATIS', 'na', 'na') pr	--Parámetros. prefijo inafectos, prefijo exento, prefijo iva
		outer apply dbo.fCfdiImpuestosSop(tv.sopnumbe, tv.soptype, 0, pr.param1, '01') xnr  --exonerado
		outer apply dbo.fCfdiImpuestosSop(tv.sopnumbe, tv.soptype, 0, pr.param2, '01') exe	--exento/inafecto
		outer apply dbo.fCfdiImpuestosSop(tv.sopnumbe, tv.soptype, 0, pr.param3, '01') iva	--iva
		outer apply dbo.fCfdiImpuestosSop(tv.sopnumbe, tv.soptype, 0, pr.param4, '02') gra	--gratuito
		outer apply dbo.fnCfdGetDireccionesCorreo(tv.custnmbr) mail
		outer apply dbo.fCfdiPagoSimultaneoMayor(tv.soptype, tv.sopnumbe, 1) pg

go

IF (@@Error = 0) PRINT 'Creación exitosa de la función: vwCfdiGeneraDocumentoDeVenta ()'
ELSE PRINT 'Error en la creación de la función: vwCfdiGeneraDocumentoDeVenta ()'
GO
-----------------------------------------------------------------------------------------
IF (OBJECT_ID ('dbo.vwCfdiTransaccionesDeVenta', 'V') IS NULL)
   exec('create view dbo.vwCfdiTransaccionesDeVenta as SELECT 1 as t');
go

alter view dbo.vwCfdiTransaccionesDeVenta as
--Propósito. Todos los documentos de venta: facturas y notas de crédito. 
--Usado por. App Factura digital (doodads)
--Requisitos. El estado "no emitido" indica que no se ha emitido el archivo xml pero que está listo para ser generado.
--			El estado "inconsistente" indica que existe un problema en el folio o certificado, por tanto no puede ser generado.
--			El estado "emitido" indica que el archivo xml ha sido generado y sellado por el PAC y está listo para ser impreso.
--06/11/17 jcf Creación cfdi Perú
--

select tv.estadoContabilizado, tv.soptype, tv.docid, tv.sopnumbe, tv.fechahora, 
	tv.CUSTNMBR, tv.nombreCliente, tv.idImpuestoCliente, cast(tv.total as numeric(19,2)) total, tv.montoActualOriginal, tv.voidstts, 

	isnull(lf.estado, isnull(fv.estado, 'inconsistente')) estado,
	case when isnull(lf.estado, isnull(fv.estado, 'inconsistente')) = 'inconsistente' 
		then 'folio o certificado inconsistente'
		else ISNULL(lf.mensaje, tv.estadoContabilizado)
	end mensaje,
	case when isnull(lf.estado, isnull(fv.estado, 'inconsistente')) = 'no emitido' 
		then null	--dbo.fCfdiGeneraDocumentoDeVentaXML (tv.soptype, tv.sopnumbe) 
		else cast('' as xml) 
	end comprobanteXml,
	
	fv.ID_Certificado, fv.ruta_certificado, fv.ruta_clave, fv.contrasenia_clave, 
	isnull(pa.ruta_certificado, '_noexiste') ruta_certificadoPac, isnull(pa.ruta_clave, '_noexiste') ruta_clavePac, isnull(pa.contrasenia_clave, '') contrasenia_clavePac, 
	emi.TAXREGTN rfc, 
	isnull(lf.noAprobacion, '') regimen, 
	emi.INET7 rutaXml, 
	emi.ZIPCODE codigoPostal,
	isnull(lf.estadoActual, '000000') estadoActual, 
	isnull(lf.mensajeEA, tv.estadoContabilizado) mensajeEA,
	tv.curncyid isocurrc,
	null addenda
from dbo.vwCfdiSopTransaccionesVenta tv
	cross join dbo.fCfdiEmisor() emi
	outer apply dbo.fCfdiCertificadoVigente(tv.fechahora) fv
	outer apply dbo.fCfdiCertificadoPAC(tv.fechahora) pa
	left join cfdlogfacturaxml lf
		on lf.soptype = tv.SOPTYPE
		and lf.sopnumbe = tv.sopnumbe
		and lf.estado = 'emitido'

go

IF (@@Error = 0) PRINT 'Creación exitosa de la vista: vwCfdiTransaccionesDeVenta'
ELSE PRINT 'Error en la creación de la vista: vwCfdiTransaccionesDeVenta'
GO

-----------------------------------------------------------------------------------------
--IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[vwCfdiDocumentosAImprimir]') AND OBJECTPROPERTY(id,N'IsView') = 1)
--    DROP view dbo.[vwCfdiDocumentosAImprimir];
--GO
IF (OBJECT_ID ('dbo.vwCfdiDocumentosAImprimir', 'V') IS NULL)
   exec('create view dbo.vwCfdiDocumentosAImprimir as SELECT 1 as t');
go

alter view dbo.vwCfdiDocumentosAImprimir as
--Propósito. Lista los documentos de venta que están listos para imprimirse: facturas y notas de crédito. 
--06/11/17 jcf Creación cfdi Perú ubl 2.0
--23/05/18 jcf Agrega estadoContabilizado
--
select tv.estadoContabilizado, tv.soptype, tv.sopnumbe, tv.fechaEmision fechaHoraEmision, 
	rtrim(td.dscriptn) tipoDocCliente, 
	tv.receptorNroDoc rfcReceptor, tv.receptorNombre nombreCliente, tv.total, tv.moneda isocurrc, --tv.mensajeEA, 
	tv.tipoDocumento TipoDeComprobante,
	case when tv.tipoDocumento = '01' then 'FACTURA ELECTRONICA'
		WHEN tv.tipoDocumento = '08' then 'NOTA DE DEBITO ELECTRONICA'
		WHEN tv.tipoDocumento = '03' then 'BOLETA ELECTRONICA'
		WHEN tv.tipoDocumento = '08' then 'NOTA DE DEBITO ELECTRONICA'
		WHEN tv.tipoDocumento = '07' then 'NOTA DE CREDITO ELECTRONICA'
		else 'OTRO' 
	end tdcmp_descripcion,

		tv.tipoOperacion,
		tv.descuento,
		tv.ORTDISAM,
		tv.ivaImponible,
		tv.iva,
		tv.inafecta,
		tv.exonerado,
		tv.gratuito,

		--Para NC:
		tv.discrepanciaDesc,
	
	--Datos del xml sellado por el PAC:
	'' SelloCFD, 
	'1/1/1900' FechaTimbrado, 
	'' folioFiscal, 
	'' NoCertificadoSAT, 
	'' [Version], 
	'' selloSAT, 
	'' formaDePago,			'NA' frpg_descripcion,
	'' Sello, 
	'' NoCertificadoCSD, 
	'' metodoDePago,			'NA' mtdpg_descripcion,
	'' RfcPAC,
	'' Leyenda,
	'' cadenaOriginalSAT
from vwCfdiGeneraDocumentoDeVenta tv
	left join cfdlogfacturaxml lf
		on lf.soptype = tv.SOPTYPE
		and lf.sopnumbe = tv.sopnumbe
		and lf.estado = 'emitido'
	left join nsaif_sy00102 td
		on td.nsaif_type = tv.receptorTipoDoc
go
IF (@@Error = 0) PRINT 'Creación exitosa de la vista: vwCfdiDocumentosAImprimir  '
ELSE PRINT 'Error en la creación de la vista: vwCfdiDocumentosAImprimir '
GO
-----------------------------------------------------------------------------------------

-- FIN DE SCRIPT ***********************************************


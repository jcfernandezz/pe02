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
--16/01/19 jcf Reemplaza caracteres no imprimibles en itemdesc
--
select dt.soptype, dt.sopnumbe, dt.LNITMSEQ, dt.ITEMNMBR, dt.ShipToName,
	dt.QUANTITY, dt.UOFM,
	um.UOFMLONGDESC UOFMsat,
	udmfa.descripcion UOFMsat_descripcion,
	um.UOFMLONGDESC, 
	dbo.fCfdReemplazaCaracteresNI(dt.ITEMDESC) ITEMDESC,
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

create function dbo.fCfdiImpuestosSop(@SOPNUMBE char(21), @DOCTYPE smallint, @LNITMSEQ int, @prefijo varchar(15), @tipoTributo varchar(10))
returns table
as
--Propósito. Detalle de impuestos en trabajo e históricos de SOP. Filtra los impuestos requeridos por @prefijo
--Requisitos. Los impuestos iva deben ser configurados con un prefijo constante
--27/11/17 jcf Creación 
--13/08/18 jcf Agrega txdtlbse
--14/11/18 jcf Ajustes para ubl2.1
--
return
(
	select TOP 1 imp.soptype, imp.sopnumbe, imp.taxdtlid, imp.staxamnt, imp.orslstax, imp.tdttxsls, imp.ortxsls,
			tx.NAME, tx.cntcprsn, tx.TXDTLPCT, tx.txdtlbse, tx.address1
	from sop10105 imp
		inner join tx00201 tx
		on tx.taxdtlid = imp.taxdtlid
		and tx.cntcprsn like @tipoTributo
	where imp.sopnumbe = @SOPNUMBE
	and imp.soptype = @DOCTYPE
	and imp.LNITMSEQ = @LNITMSEQ
	and imp.taxdtlid like @prefijo + '%'
)

go


IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiImpuestosSop()'
ELSE PRINT 'Error en la creación de la función: fCfdiImpuestosSop()'
GO

----------------------------------------------------------------------------------------------------
IF OBJECT_ID ('dbo.fCfdiImpuestosAgrupadosSop') IS NOT NULL
   DROP FUNCTION dbo.fCfdiImpuestosAgrupadosSop
GO

create function dbo.fCfdiImpuestosAgrupadosSop(@SOPNUMBE char(21), @DOCTYPE smallint, @LNITMSEQ int, @prefijo varchar(15), @tipoTributo varchar(10), @tipoAfectacion varchar(2))
returns table
as
--Propósito. Agrupa los impuestos en trabajo e históricos de SOP. Filtra los impuestos requeridos por @prefijo
--Requisitos. Los impuestos iva deben ser configurados con un prefijo constante
--19/11/18 jcf Creación ubl2.1
--
return
(
	select imp.soptype, imp.sopnumbe, imp.taxdtlid, 
			imp.NAME, imp.cntcprsn, imp.TXDTLPCT, imp.txdtlbse, imp.address1,
			sum(imp.staxamnt) staxamnt, sum(imp.orslstax) orslstax, sum(imp.tdttxsls) tdttxsls, sum(imp.ortxsls) ortxsls
	from dbo.fCfdiImpuestosSop(@SOPNUMBE, @DOCTYPE , @LNITMSEQ , @prefijo , @tipoTributo ) imp
	where imp.name like @tipoAfectacion
	group by imp.soptype, imp.sopnumbe, imp.taxdtlid, 
			imp.NAME, imp.cntcprsn, imp.TXDTLPCT, imp.txdtlbse, imp.address1
)

go


IF (@@Error = 0) PRINT 'Creación exitosa de la función: fCfdiImpuestosAgrupadosSop()'
ELSE PRINT 'Error en la creación de la función: fCfdiImpuestosAgrupadosSop()'
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
--14/11/18 jcf Cambios para ubl 2.1
--13/12/18 jcf Agrega imponibles de inafecto, exonerado, exporta, gratuito
--
		select ROW_NUMBER() OVER(ORDER BY Concepto.LNITMSEQ asc) id, 
			Concepto.soptype, Concepto.sopnumbe, Concepto.LNITMSEQ, rtrim(Concepto.ITEMNMBR) ITEMNMBR, '' SERLTNUM, 
			Concepto.ITEMDESC, Concepto.CMPNTSEQ, 
			rtrim(Concepto.UOFMsat) udemSunat,
			Concepto.uscatvls_6 claveProdSunat,
			'' NoIdentificacion,
			dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(Concepto.ITEMDESC))), 10) Descripcion, 

			case when isnull(iva.txdtlbse, 3) = 1 then			--igv incluído
					(Concepto.OXTNDPRC + Concepto.descuento)/Concepto.QUANTITY
				else
					(Concepto.OXTNDPRC + Concepto.descuento + isnull(iva.orslstax, 0.00))/Concepto.QUANTITY 
			end precioUniConIva,								--precioReferencial unitario con igv y antes de descuento

			case when isnull(iva.txdtlbse, 3) = 1 then			--igv incluído
					(Concepto.OXTNDPRC + Concepto.descuento - isnull(iva.orslstax, 0.00))/Concepto.QUANTITY
				else
					(Concepto.OXTNDPRC + Concepto.descuento)/Concepto.QUANTITY
			end valorUni,										--valor unitario sin igv y antes de descuento

			case when isnull(iva.txdtlbse, 3) = 1 then			--igv incluído
					Concepto.OXTNDPRC - isnull(iva.orslstax, 0.00)
				else Concepto.OXTNDPRC
			end + Concepto.descuento		importe,			--valor de venta QxBI (totalVenta no incluye igv, antes de descuento)

			Concepto.QUANTITY cantidad, 

			Concepto.descuento,
			Concepto.OXTNDPRC + Concepto.descuento descuentoBaseImponible,
			Concepto.descuento / (Concepto.OXTNDPRC + Concepto.descuento) descuentoPorcentaje,
			case when isnull(iva.txdtlbse, 3) = 1 and Concepto.descuento != 0 then			--igv incluído
				'01'		--descuento no afecta la base imponible
				else '00'	--descuento sí afecta la base imponible
			end descuentoCodigo,

			isnull(iva.orslstax, 0.00)		montoIva,				--igv
			isnull(iva.ortxsls, 0.00)		montoImponibleIva,		--igv imponible
			isnull(iva.TXDTLPCT, 0.00)/100	porcentajeIva,
			isnull(xnr.ortxsls, 0.00)		montoImponibleExonera,		
			isnull(exe.ortxsls, 0.00)		montoImponibleInafecto,		
			isnull(gra.ortxsls, 0.00)		montoImponibleGratuito,		
			isnull(xpr.ortxsls, 0.00)		montoImponibleExporta,		

			case when isnull(iva.orslstax, 0) != 0 
				then rtrim(iva.cntcprsn)
				else rtrim(isnull(xnr.cntcprsn, '')+isnull(exe.cntcprsn, '')+isnull(gra.cntcprsn, '')+isnull(xpr.cntcprsn, ''))
			end tipoTributo,

			case when isnull(iva.orslstax, 0) != 0 
				then rtrim(iva.name)
				else rtrim(isnull(xnr.name, '')+isnull(exe.name, '')+isnull(gra.name, '')+isnull(xpr.name, ''))
			end tipoAfectacion,

			case when isnull(iva.orslstax, 0) != 0 
				then case when rtrim(iva.ADDRESS1) = '0' then '0' else '1' end 
				else case when rtrim(isnull(xnr.ADDRESS1, '')+isnull(exe.ADDRESS1, '')+isnull(gra.ADDRESS1, '')+isnull(xpr.ADDRESS1, '')) = '0' then '0' else '1' end 
			end operacionOnerosa
			--case when isnull(iva.orslstax, 0) != 0 
			--	then rtrim(iva.name)
			--	else case when isnull(exe.ortxsls, 0) != 0 
			--		then rtrim(exe.name)
			--		else case when isnull(xnr.ortxsls, 0) != 0
			--			then rtrim(xnr.name)
			--			else case when isnull(gra.ortxsls, 0) != 0
			--				then rtrim(gra.name)
			--				else case when isnull(xpr.ortxsls, 0) != 0
			--					then rtrim(xpr.name)
			--					else ''
			--					end
			--				end
			--			end
			--		end
			--	end tipoAfectacion	
		from vwCfdiSopLineasTrxVentas Concepto
			outer apply dbo.fLcLvParametros('V_PREFEXONERADO', 'V_PREFEXENTO', 'V_PREFIVA', 'V_GRATIS', 'V_PREFEXPORTA', 'na') pr	--Parámetros. prefijo inafectos, prefijo exento, prefijo iva
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param3, '%') iva --iva
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param1, '%') xnr --exonerado
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param2, '%') exe --inafecto
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param4, '%') gra --gratuito
			outer apply dbo.fCfdiImpuestosSop(Concepto.SOPNUMBE, Concepto.soptype, Concepto.LNITMSEQ, pr.param5, '%') xpr --exportación
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
--08/11/18 jcf Agrega ajustes para ubl 2.1
--16/01/19 jcf Agrega dirección
--21/02/19 jcf Agrega leyenda por factura
--03/05/19 jcf Agrega leyenda por factura 2
--17/05/19 jcf Corrige codDetraccion y medioPagoDetraccion. Agrega parámetro TIPOOPERACIDFLT
--23/05/19 jcf Agrega param5: código de sucursal. Cambia origen del receptorNroDoc
--19/08/19 jcf Usa ccode para el país del receptor
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
		emi.param5									emisorUbigeo,
		emi.ADDRESS1								emisorDireccion,
		emi.ADDRESS2								emisorUrbanizacion,
		emi.[STATE]									emisorDepartamento,
		emi.COUNTY									emisorProvincia,
		emi.CITY									emisorDistrito,
		emi.CCODE									emisorCodPais,

		cmpr.nsaif_type_nit							receptorTipoDoc,
		case when tv.TXRGNNUM = '' then
			rtrim(cmpr.nsaIFNit)
		else tv.TXRGNNUM
		end											receptorNroDoc,
		tv.nombreCliente							receptorNombre,
		left(tv.address1 +' '+ tv.address2, 100)	receptorDireccion,
		tv.[state]									receptorProvincia,
		tv.ccode									receptorPais,
		tv.city										receptorCiudad,

		mail.emailTo,
		tv.send_email_statements,
		rtrim(tv.sopnumbe)							idDocumento,
		tv.docdate									fechaEmision,
		convert(varchar(10), tv.fechaHora, 108)		horaEmision,
		tv.duedate									fechaVencimiento,
		tv.curncyid									moneda,
		
		CASE when upper(pr2.param1)='NA' then	--caso en que la factura no debe usar un tipo de operación predeterminado
			rtrim(cmpr.[nsa_Cod_Transac])
		else
			rtrim(ISNULL(cmpr.[nsa_Cod_Transac], pr2.param1))	
		end											tipoOperacion,
		tv.xchgrate,

		--descuento global
		tv.ORTDISAM									descuentoGlobalMonto,
		tv.ORSUBTOT									descuentoGlobalImponible,
		case when tv.ORSUBTOT != 0 then 
			tv.ORTDISAM/tv.ORSUBTOT 
		else 0 
		end											descuentoGlobalPorcentaje,
		--el código de motivo de descuento global debe basarse en el código de descuento por producto
		
		--detracción
		rtrim(cmpr.cod_detraccion)					codigoDetraccion,
		dtr.PRCNTAGE								porcentajeDetraccion,
		round(tv.total*dtr.PRCNTAGE/100, 2)			montoDetraccion,
		case when isnull(cmpr.cod_detraccion, '') != '' then '2006' else '' end codleyendaDetraccion,
		emi.ctaBancoNacion							numCuentaBancoNacion,
		'002'										medioPagoDetraccion,	--depósito

		--totales
		--tv.docamnt,
		tv.total									montoTotalVenta,
		isnull(iva.orslstax, 0.00)					montoTotalImpuestos,
		isnull(iva.ortxsls, 0.00)					
		+ isnull(xnr.ortxsls, 0.00)					
		+ isnull(xpr.ortxsls, 0.00)					
		+ isnull(gra.ortxsls, 0.00)					
		+ isnull(exe.ortxsls, 0.00)					montoSubtotalValorVenta,
		tv.descuento								montoTotalDescuentosPorItem,
		isnull(gra.orslstax, 0.00)					montoTotalImpuOperGratuitas,
		isnull(iva.orslstax, 0.00)					montoTotalIgv,

		--subtotales
		isnull(iva.ortxsls, 0.00)					montoSubtotalIvaImponible,
		isnull(xnr.ortxsls, 0.00)					montoSubtotalExonerado,
		isnull(xpr.ortxsls, 0.00)					montoSubtotalExportacion,
		isnull(gra.ortxsls, 0.00)					montoSubtotalGratuito,
		isnull(exe.ortxsls, 0.00)					montoSubtotalInafecto,

		isnull(iva.tdttxsls, 0.00)					montoSubtotalIvaImponiblePen,
		isnull(xnr.tdttxsls, 0.00)					montoSubtotalExoneradoPen,
		isnull(xpr.tdttxsls, 0.00)					montoSubtotalExportacionPen,
		isnull(gra.tdttxsls, 0.00)					montoSubtotalGratuitoPen,
		isnull(exe.tdttxsls, 0.00)					montoSubtotalInafectoPen,

		--relación a factura o ND
		cmpr.comprobanteRelacionado					cRelacionadoNumDocAfectado,
		crel.tipo									cRelacionadoTipoDocAfectado,
		right(rtrim(cmpr.nsa_Cred_Trib),2)			infoRelNotasCodigoTipoNota,
		dbo.fCfdReemplazaSecuenciaDeEspacios(rtrim(dbo.fCfdReemplazaCaracteresNI(cmpr.motivoNCND)), 10)	infoRelNotasObservaciones,

		case when isnull(gra.ortxsls, 0.00) != 0.00  
				and isnull(iva.ortxsls, 0.00) = 0.00 and isnull(xnr.ortxsls, 0.00) = 0.00 and isnull(xpr.ortxsls, 0.00) = 0.00	and isnull(exe.ortxsls, 0.00) = 0.00 then
			'1002' 
			else '' 
		end codleyendaTransfGratuita,
		UPPER(DBO.TII_INVOICE_AMOUNT_LETTERS(tv.total, default)) montoEnLetras,
		tv.estadoContabilizado, tv.docdate,
		case when upper(pr.param6) = 'SI' then rtrim(tv.comment_1) else '' end leyendaPorFactura,	--va en la parte inferior Info adicional de la impresión de factura
		case when upper(pr.param6) = 'SI' then rtrim(lfa.memo) else '' end leyendaPorFactura2		--va en la sección del adquiriente en la impresión de factura

	from dbo.vwCfdiSopTransaccionesVenta tv
		cross join dbo.fCfdiEmisor() emi
		outer apply dbo.fLcLvComprobanteSunat (tv.soptype, tv.sopnumbe)  cmpr
		left join nsaCOA_Reten_iva dtr
			on dtr.nsa_Cod_IVA1 = cmpr.cod_detraccion
		outer apply dbo.fLcLvComprobanteSunat (cmpr.comprobanteRelacionadoSoptype, cmpr.comprobanteRelacionado)  crel
		outer apply dbo.fCfdiParametros('V_PREFEXONERADO', 'V_PREFEXENTO', 'V_PREFIVA', 'V_GRATIS', 'V_PREFEXPORTA', 'V_LEYENDAPORFAC', 'LCLV') pr	--Parámetros. prefijo inafectos, prefijo exento, prefijo iva
		outer apply dbo.fCfdiParametros('TIPOOPERACIDFLT', 'NA', 'NA', 'NA', 'NA', 'NA', 'LCLV') pr2
		outer apply dbo.fCfdiImpuestosAgrupadosSop(tv.sopnumbe, tv.soptype, 0, pr.param1, '9997', '%') xnr	--exonerado
		outer apply dbo.fCfdiImpuestosAgrupadosSop(tv.sopnumbe, tv.soptype, 0, pr.param2, '9998', '%') exe	--exento/inafecto
		outer apply dbo.fCfdiImpuestosAgrupadosSop(tv.sopnumbe, tv.soptype, 0, pr.param3, '1000', '%') iva	--iva
		outer apply dbo.fCfdiImpuestosAgrupadosSop(tv.sopnumbe, tv.soptype, 0, pr.param4, '9996', '%') gra	--gratuito
		outer apply dbo.fCfdiImpuestosAgrupadosSop(tv.SOPNUMBE, tv.soptype, 0, pr.param5, '9995', '%') xpr	--exportación
		outer apply dbo.fnCfdGetDireccionesCorreo(tv.custnmbr) mail
		outer apply dbo.fCfdiGetLeyendaDeFactura(tv.SOPNUMBE, tv.soptype, '01') lfa

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
--IF (OBJECT_ID ('dbo.vwCfdiDocumentosAImprimir', 'V') IS NULL)
--   exec('create view dbo.vwCfdiDocumentosAImprimir as SELECT 1 as t');
--go

--alter view dbo.vwCfdiDocumentosAImprimir as
----Propósito. Lista los documentos de venta que están listos para imprimirse: facturas y notas de crédito. 
----06/11/17 jcf Creación cfdi Perú ubl 2.0
----23/05/18 jcf Agrega estadoContabilizado
----
--select tv.estadoContabilizado, tv.soptype, tv.sopnumbe, tv.fechaEmision fechaHoraEmision, 
--	rtrim(td.dscriptn) tipoDocCliente, 
--	tv.receptorNroDoc rfcReceptor, tv.receptorNombre nombreCliente, tv.montoTotalVenta, tv.moneda isocurrc, --tv.mensajeEA, 
--	tv.tipoDocumento TipoDeComprobante,
--	case when tv.tipoDocumento = '01' then 'FACTURA ELECTRONICA'
--		WHEN tv.tipoDocumento = '08' then 'NOTA DE DEBITO ELECTRONICA'
--		WHEN tv.tipoDocumento = '03' then 'BOLETA ELECTRONICA'
--		WHEN tv.tipoDocumento = '08' then 'NOTA DE DEBITO ELECTRONICA'
--		WHEN tv.tipoDocumento = '07' then 'NOTA DE CREDITO ELECTRONICA'
--		else 'OTRO' 
--	end tdcmp_descripcion,

--		tv.tipoOperacion,
----		tv.descuentoGlobalMonto,
--		tv.descuentoGlobalMonto,
--		tv.montoSubtotalIvaImponible,
--		tv.montoTotalImpuestos,
--		tv.montoSubtotalInafecto,
--		tv.montoSubtotalExonerado,
--		tv.montoSubtotalGratuito,

--		--Para NC:
--		tv.relNotas_observaciones
	
--from vwCfdiGeneraDocumentoDeVenta tv
--	left join cfdlogfacturaxml lf
--		on lf.soptype = tv.SOPTYPE
--		and lf.sopnumbe = tv.sopnumbe
--		and lf.estado = 'emitido'
--	left join nsaif_sy00102 td
--		on td.nsaif_type = tv.receptorTipoDoc
--go
--IF (@@Error = 0) PRINT 'Creación exitosa de la vista: vwCfdiDocumentosAImprimir  '
--ELSE PRINT 'Error en la creación de la vista: vwCfdiDocumentosAImprimir '
--GO
-------------------------------------------------------------------------------------------

-- FIN DE SCRIPT ***********************************************


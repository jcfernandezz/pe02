
IF (OBJECT_ID ('dbo.TII_SOPINVOICE', 'V') IS NULL)
   exec('create view dbo.TII_SOPINVOICE as SELECT 1 as t');
go

ALTER VIEW [dbo].[TII_SOPINVOICE] AS 
--Prop�sito. Representaci�n impresa de factura electr�nica Per�. Habilitar codigoBarras si usa Crystal!
--20/11/17 jcf Modifica estructura detalle sop para cfdi Per� ubl 2
--
SELECT 
		SOPHEADER.DOCSTATUS,
		SOPHEADER.SOPTYPE,
		rtrim(SOPHEADER.SOPNUMBE) SOPNUMBE,
		SOPHEADER.ORIGNUMB,
		SOPHEADER.DOCDATE,
		SOPHEADER.GLPOSTDT,
		SOPHEADER.DUEDATE,
		SOPHEADER.PYMTRMID,
		SOPHEADER.LOCNCODE,
		SOPHEADER.CUSTNMBR,
		SOPHEADER.CUSTNAME,
		SOPHEADER.CSTPONBR,
		SOPHEADER.PRBTADCD,
		SOPHEADER.PRSTADCD,
		SOPHEADER.ShipToName,
		SOPHEADER.ADDRESS1,
		case when patindex('%#%', SOPHEADER.address1) = 0 then 
			'-'
		else right(rtrim(SOPHEADER.address1), len(SOPHEADER.address1)-patindex('%#%', SOPHEADER.address1)) 
		end noExterior,
		SOPHEADER.ADDRESS2,
		SOPHEADER.ADDRESS3,
		SOPHEADER.CITY,
		SOPHEADER.STATE,
		SOPHEADER.ZIPCODE,
		SOPHEADER.CCode,
		SOPHEADER.COUNTRY,
		SOPHEADER.PHNUMBR1,
		SOPHEADER.PHNUMBR2,
		SOPHEADER.PHONE3,
		SOPHEADER.FAXNUMBR,
		SOPHEADER.SHIPMTHD,
		SOPHEADER.SUBTOTAL,
		SOPHEADER.ORSUBTOT,
		SOPHEADER.OREMSUBT,
		--SOPHEADER.ORTDISAM,
		SOPHEADER.ORMRKDAM,
		SOPHEADER.FRTAMNT,
		SOPHEADER.ORFRTAMT,
		SOPHEADER.MISCAMNT,
		SOPHEADER.ORMISCAMT,
		SOPHEADER.TXRGNNUM,
		SOPHEADER.TAXAMNT,
		SOPHEADER.ORTAXAMT,
		SOPHEADER.DOCAMNT,
		CASE
			WHEN SOPELECTINV.isocurrc = 'PEN' THEN UPPER(DBO.TII_INVOICE_AMOUNT_LETTERS(SOPHEADER.ORDOCAMT, '')) + ' SOLES'
			WHEN SOPELECTINV.isocurrc = 'USD' THEN UPPER(DBO.TII_INVOICE_AMOUNT_LETTERS(SOPHEADER.ORDOCAMT, '')) + ' DOLARES AMERICANOS'
		ELSE
			UPPER(DBO.TII_INVOICE_AMOUNT_LETTERS(SOPHEADER.ORDOCAMT, default)) 
		END  AS AMOUNT_LETTERS,
		SOPHEADER.ORDOCAMT,
		SOPHEADER.CURNCYID,
		SOPHEADER.RATETPID,
		SOPHEADER.EXGTBLID,
		SOPHEADER.XCHGRATE,
		SOPELECTINV.isocurrc,
		cm.USERDEF1,
		SOPELECTINV.metodoDePago USRTAB01,
		SOPELECTINV.metodoDePago,
		SOPELECTINV.mtdpg_descripcion,
		SOPELECTINV.TipoDeComprobante,
		SOPELECTINV.tdcmp_descripcion,
		SOPELECTINV.tipoOperacion,
		SOPELECTINV.descuento,
		SOPELECTINV.ORTDISAM,
		SOPELECTINV.ivaImponible,
		SOPELECTINV.iva,

		SOPELECTINV.inafecta,
		SOPELECTINV.exonerado,
		SOPELECTINV.gratuito,

		--Para NC:
		SOPELECTINV.discrepanciaDesc,
		--SOPELECTINV.codigoPostal,
		--SOPELECTINV.regimenFiscal,
		--SOPELECTINV.rgfs_descripcion,
		--SOPELECTINV.usoCfdi,
		--SOPELECTINV.uscf_descripcion,
		--RMCUSTOMER.TXRGNNUM AS TXRGNNUMCUST,
		SOPDETAIL.LNITMSEQ,
		SOPDETAIL.LNITMSEQ / 16384 ORDEN,
		SOPDETAIL.CMPNTSEQ,
		SOPDETAIL.ITEMNMBR,
		--SOPDETAIL.ClaveProdServ,
		SOPDETAIL.ITEMDESC,
		SOPDETAIL.udemSunat UOFM,
		--SOPDETAIL.UOFMsat_descripcion,
		SOPDETAIL.valorUni ORUNTPRC,
		SOPDETAIL.Importe OXTNDPRC,
		SOPDETAIL.descuento ormrkdamDetail,
		SOPDETAIL.Cantidad QUANTITY,
		SOPDETAILSERIALLOT.SERLTNUM,
		--SOPELECTINV.TipoRelacion,
		--SOPELECTINV.tprl_descripcion,
		--SOPELECTINV.UUIDrelacionado,
		ISNULL(SOPDETAILSERIALLOT.SERLTQTY, SOPDETAIL.Cantidad) SERLTQTY,
		SOPDETAILSERIALLOT.BIN,
		SOPDETAILSERIALLOT.LOTATRB1,
		SOPDETAILSERIALLOT.LOTATRB2,
		SOPDETAILSERIALLOT.LOTATRB3,
		SOPDETAILSERIALLOT.LOTATRB4,
		SOPDETAILSERIALLOT.LOTATRB5,
		RTRIM(SOPINVOICEINFO.ADRSCODE) AS ADRSCODE_INVOICE,
		RTRIM(SOPINVOICEINFO.SHIPMTHD) AS SHIPMTHD_INVOICE,
		RTRIM(SOPINVOICEINFO.CNTCPRSN) AS CNTCPRSN_INVOICE,
		RTRIM(SOPINVOICEINFO.ADDRESS1) AS ADDRESS1_INVOICE,
		RTRIM(SOPINVOICEINFO.ADDRESS2) AS ADDRESS2_INVOICE,
		RTRIM(SOPINVOICEINFO.ADDRESS3) AS ADDRESS3_INVOICE,
		RTRIM(SOPINVOICEINFO.CCode) AS CCode_INVOICE,
		RTRIM(SOPINVOICEINFO.COUNTRY) AS COUNTRY_INVOICE,
		RTRIM(SOPINVOICEINFO.CITY) AS CITY_INVOICE,
		RTRIM(SOPINVOICEINFO.STATE) AS STATE_INVOICE,
		RTRIM(SOPINVOICEINFO.ZIP) AS ZIP_INVOICE,
		RTRIM(SOPINVOICEINFO.PHONE1) AS PHONE1_INVOICE,
		RTRIM(SOPINVOICEINFO.PHONE2) AS PHONE2_INVOICE,
		RTRIM(SOPINVOICEINFO.PHONE3) AS PHONE3_INVOICE,
		RTRIM(SOPINVOICEINFO.FAX) AS FAX_INVOICE,
		RTRIM(SOPSHIPMENTINFO.ADRSCODE) AS ADRSCODE_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.SHIPMTHD) AS SHIPMTHD_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.CNTCPRSN) AS CNTCPRSN_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.ADDRESS1) AS ADDRESS1_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.ADDRESS2) AS ADDRESS2_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.ADDRESS3) AS ADDRESS3_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.CCode) AS CCode_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.COUNTRY) AS COUNTRY_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.CITY) AS CITY_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.STATE) AS STATE_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.ZIP) AS ZIP_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.PHONE1) AS PHONE1_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.PHONE2) AS PHONE2_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.PHONE3) AS PHONE3_SHIPMENT,
		RTRIM(SOPSHIPMENTINFO.FAX) AS FAX_SHIPMENT,
		--SOPELECTINV.docid,
		RIGHT('0' + CAST(DAY(SOPELECTINV.fechaHoraEmision) AS VARCHAR(2)),2) + '/' + RIGHT('0' + CAST(MONTH(SOPELECTINV.fechaHoraEmision) AS VARCHAR(2)),2) + '/' + CAST(YEAR(SOPELECTINV.fechaHoraEmision) AS CHAR(4)) + ' ' + RIGHT('0' + CAST(DATEPART(HOUR,SOPELECTINV.fechaHoraEmision) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(MINUTE,SOPELECTINV.fechaHoraEmision) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(SECOND,SOPELECTINV.fechaHoraEmision) AS VARCHAR(2)),2) AS fechaHoraEmision,
		SOPELECTINV.tipoDocCliente,
		SOPELECTINV.rfcReceptor,
		SOPELECTINV.nombreCliente,
		SOPELECTINV.total,
		RTRIM(SOPELECTINV.formaDePago) AS formaDePago,
		SOPELECTINV.frpg_descripcion,
		SOPELECTINV.folioFiscal,
		SOPELECTINV.noCertificadoCSD,
		SOPELECTINV.version,
		SOPELECTINV.selloCFD,
		SOPELECTINV.selloSAT,
		SOPELECTINV.cadenaOriginalSAT,
		SOPELECTINV.noCertificadoSAT,
		SOPELECTINV.RfcPAC,
		SOPELECTINV.Leyenda,
		RIGHT('0' + CAST(DAY(SOPELECTINV.FechaTimbrado) AS VARCHAR(2)),2) + '/' + RIGHT('0' + CAST(MONTH(SOPELECTINV.FechaTimbrado) AS VARCHAR(2)),2) + '/' + CAST(YEAR(SOPELECTINV.FechaTimbrado) AS CHAR(4)) + ' ' + RIGHT('0' + CAST(DATEPART(HOUR,SOPELECTINV.FechaTimbrado) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(MINUTE,SOPELECTINV.FechaTimbrado) AS VARCHAR(2)),2) + ':' + RIGHT('0' + CAST(DATEPART(SECOND,SOPELECTINV.FechaTimbrado) AS VARCHAR(2)),2) AS FechaTimbrado,
		dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(RTRIM(substring(cm.cmmttext, 1, 350))), 10) addLeyenda,
		 
		case when rel.tipoDocumento = '01' then 'FACTURA ELECTRONICA'
				WHEN rel.tipoDocumento = '03' then 'BOLETA ELECTRONICA'
				When isnull(rel.tipoDocumento, '') = '' then ''
				ELSE 'OTRO'
		end tipoDocumentoRel,
		rel.sopNumbeTo sopNumbeRel,
		gr.DOCNUMBR guiaNumbe

		--RTRIM(SOPELECTINV.rutaYNomArchivo) AS rutaYNomArchivo,
		--RTRIM(SOPELECTINV.rutaYNomArchivoNet) AS rutaYNomArchivoNet
		--dbo.fCfdObtieneImagenC(SOPELECTINV.rutaYNomArchivo) codigoBarras
FROM
(
		-- ENCABEZADO DE FACTURAS SOP EN LOTE
		SELECT
				'Sin Contabilizar' as DOCSTATUS,
				SOPTYPE,
				SOPNUMBE,
				DOCDATE,
				ORIGNUMB,
				GLPOSTDT,
				DUEDATE,
				PYMTRMID,
				LOCNCODE,
				CUSTNMBR,
				CUSTNAME,
				CSTPONBR,
				PRBTADCD,
				PRSTADCD,
				ShipToName,
				ADDRESS1,
				ADDRESS2,
				ADDRESS3,
				CITY,
				STATE,
				ZIPCODE,
				CCode,
				COUNTRY,
				PHNUMBR1,
				PHNUMBR2,
				PHONE3,
				FAXNUMBR,
				SHIPMTHD,
				SUBTOTAL,
				ORSUBTOT,
				OREMSUBT,
				ORTDISAM,
				ORMRKDAM,
				FRTAMNT,
				ORFRTAMT,
				MISCAMNT,
				ORMISCAMT,
				TXRGNNUM,
				TAXAMNT,
				ORTAXAMT,
				DOCAMNT,
				ORDOCAMT,
				CURNCYID,
				RATETPID,
				EXGTBLID,
				XCHGRATE		
		FROM 
				SOP10100 WITH (NOLOCK)
		WHERE 
				SOPTYPE IN (3,4) -- 3 FACTURA / 4 DEVOLUCION

		UNION ALL

		-- ENCABEZADO DE FACTURAS SOP CONTABILIZADAS
		SELECT 
				'Contabilizado' as DOCSTATUS,
				SOPTYPE,
				SOPNUMBE,
				DOCDATE,
				ORIGNUMB,
				GLPOSTDT,
				DUEDATE,
				PYMTRMID,
				LOCNCODE,
				CUSTNMBR,
				CUSTNAME,
				CSTPONBR,
				PRBTADCD,
				PRSTADCD,
				ShipToName,
				ADDRESS1,
				ADDRESS2,
				ADDRESS3,
				CITY,
				STATE,
				ZIPCODE,
				CCode,
				COUNTRY,
				PHNUMBR1,
				PHNUMBR2,
				PHONE3,
				FAXNUMBR,
				SHIPMTHD,
				SUBTOTAL,
				ORSUBTOT,
				OREMSUBT,
				ORTDISAM,
				ORMRKDAM,
				FRTAMNT,
				ORFRTAMT,
				MISCAMNT,
				ORMISCAMT,
				TXRGNNUM,
				TAXAMNT,
				ORTAXAMT,
				DOCAMNT,
				ORDOCAMT,
				CURNCYID,
				RATETPID,
				EXGTBLID,
				XCHGRATE
		FROM 
				SOP30200 WITH (NOLOCK)
		WHERE 
				SOPTYPE IN (3,4) -- 3 FACTURA / 4 DEVOLUCION
		
) SOPHEADER

left join dbo.vwCfdiConceptos SOPDETAIL
	on SOPDETAIL.soptype = SOPHEADER.soptype
	and SOPDETAIL.sopnumbe = SOPHEADER.sopnumbe

LEFT OUTER JOIN

(

-- DATOS DE LOTES/SERIES UTILIZADOS EN TRX DE VENTAS (TANTO EN LOTE COMO CONTABILIZADAS)
SELECT 
		A.SOPTYPE,
		A.SOPNUMBE,
		A.LNITMSEQ,
		CMPNTSEQ,
		A.SERLTNUM,
		A.SERLTQTY,
		A.ITEMNMBR,
		A.BIN,
		B.LOTATRB1,
		B.LOTATRB2,
		B.LOTATRB3,
		B.LOTATRB4,
		B.LOTATRB5
FROM 
		SOP10201 A WITH (NOLOCK) INNER JOIN
		IV00301 B WITH (NOLOCK) ON A.ITEMNMBR = B.ITEMNMBR AND A.SERLTNUM = B.LOTNUMBR
WHERE 
		A.SOPTYPE IN (3,4) -- 3 FACTURA / 4 DEVOLUCION
) SOPDETAILSERIALLOT

	ON SOPDETAIL.SOPTYPE = SOPDETAILSERIALLOT.SOPTYPE AND SOPDETAIL.SOPNUMBE = SOPDETAILSERIALLOT.SOPNUMBE AND SOPDETAIL.LNITMSEQ = SOPDETAILSERIALLOT.LNITMSEQ AND SOPDETAIL.CMPNTSEQ = SOPDETAILSERIALLOT.CMPNTSEQ
	
INNER JOIN RM00102 AS SOPINVOICEINFO WITH (NOLOCK)
	ON SOPHEADER.PRBTADCD = SOPINVOICEINFO.ADRSCODE AND SOPHEADER.CUSTNMBR = SOPINVOICEINFO.CUSTNMBR

INNER JOIN RM00102 as SOPSHIPMENTINFO WITH (NOLOCK)
	ON SOPHEADER.PRSTADCD = SOPSHIPMENTINFO.ADRSCODE AND SOPHEADER.CUSTNMBR = SOPSHIPMENTINFO.CUSTNMBR

--INNER JOIN RM00101 as RMCUSTOMER WITH (NOLOCK)
--	ON SOPHEADER.CUSTNMBR = RMCUSTOMER.CUSTNMBR

LEFT OUTER JOIN dbo.vwCfdiDocumentosAImprimir SOPELECTINV WITH (NOLOCK)
	ON SOPHEADER.SOPTYPE = SOPELECTINV.soptype 
	AND SOPHEADER.SOPNUMBE = SOPELECTINV.sopnumbe

outer apply dbo.fCfdiRelacionados(SOPHEADER.soptype, SOPHEADER.sopnumbe) rel

left join sop10106 cm
	on cm.sopnumbe = SOPHEADER.sopnumbe
	and cm.soptype = SOPHEADER.soptype

left join tblGREM001 gr
	on gr.GREMReferenciaNumb = SOPHEADER.sopnumbe
	and gr.GREMReferenciaTipo = SOPHEADER.soptype
	and gr.GREMGuiaIndicador = 1 --GUIA DE REMISION DE FACTURA


GO


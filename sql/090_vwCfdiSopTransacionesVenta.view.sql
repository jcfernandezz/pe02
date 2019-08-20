IF (OBJECT_ID ('dbo.vwCfdiSopTransaccionesVenta', 'V') IS NULL)
   exec('create view dbo.vwCfdiSopTransaccionesVenta as SELECT 1 as t');
go

alter view dbo.vwCfdiSopTransaccionesVenta
--Propósito. Obtiene las transacciones de venta SOP. 
--Utiliza:	vwRmTransaccionesTodas
--Requisitos. No muestra facturas registradas en cuentas por cobrar. 
--24/10/17 jcf Creación cfdi Perú
--06/06/18 jcf Agrega docamnt, trdisamt
--08/11/18 jcf Agrega send_email_statements
--19/11/18 jcf Agrega ORSUBTOT, fechaHora
--23/05/19 jcf Agrega txrgnnum
--19/08/19 jcf Agrega ccode
--
AS

SELECT	'contabilizado' estadoContabilizado,
		case when cn.TXRGNNUM = '' 
			then rtrim(dbo.fCfdReemplazaCaracteresNI(replace(cab.custnmbr, '-', '')))
			else rtrim(dbo.fCfdReemplazaCaracteresNI(rtrim(left(replace(cn.TXRGNNUM, '-', ''), 23))))	--loc argentina usa los 23 caracteres de la izquierda
		end idImpuestoCliente,
		rtrim(dbo.fCfdReemplazaCaracteresNI(rtrim(replace(cn.TXRGNNUM, '-', '')))) TXRGNNUM,
		cab.CUSTNMBR,
		dbo.fCfdReemplazaSecuenciaDeEspacios(ltrim(rtrim(dbo.fCfdReemplazaCaracteresNI(cab.CUSTNAME))), 10)	nombreCliente,
		rtrim(cab.docid) docid, cab.SOPTYPE, 
		rtrim(cab.sopnumbe) sopnumbe, 
		cab.docdate, 
		dateadd(HOUR, convert(int, isnull(p.param1, '0')), cab.dex_row_ts) fechaHora,
		cab.ORDOCAMT total,	cab.ORSUBTOT, cab.ORSUBTOT + cab.ORMRKDAM subtotal, cab.ORTAXAMT impuesto, cab.ORMRKDAM, cab.ORTDISAM, cab.ORMRKDAM + cab.ORTDISAM descuento, 
		cab.docamnt, cab.trdisamt, 
		cab.orpmtrvd, rtrim(mo.isocurrc) curncyid, 
		case when cab.xchgrate <= 0 then 1 else cab.xchgrate end xchgrate, 
		cab.voidStts + isnull(rmx.voidstts, 0) voidstts, rmx.montoActualOriginal,
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.address1), 10)) address1, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.address2), 10)) address2, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.address3), 10)) address3, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.city), 10)) city, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.[STATE]), 10)) [state], 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.country), 10)) country, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.CCode), 10)) ccode, 
		right('00000'+dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.zipcode), 10), 5) zipcode, 
		cn.send_email_statements,
		cab.duedate, cab.pymtrmid, cab.glpostdt, 
		dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.cstponbr), 10) cstponbr,
		da.USRDEF05, isnull(da.usrtab01, '') usrtab01, cab.commntid, isnull(da.comment_1, '') comment_1,
		cab.dex_row_id
  from	sop30200 cab							--sop_hdr_hist
		inner join vwCfdIdDocumentos id
			on id.docid = cab.DOCID
        left outer join RM00101 cn				--rm_customer_mstr
			on cn.CUSTNMBR = cab.CUSTNMBR
		left outer join vwRmTransaccionesTodas rmx
             ON rmx.RMDTYPAL in (1, 8)			-- 1 invoice, 8 return
            and rmx.bchsourc = 'Sales Entry'	-- incluye sop
            and (cab.sopType-2 = rmx.rmdTypAl or cab.sopType+4 = rmx.rmdTypAl) --elimina la posibilidad de repetidos
            and cab.sopnumbe = rmx.DOCNUMBR
		left outer join dynamics..mc40200 mo
			on mo.CURNCYID = cab.curncyid
		outer apply dbo.fCfdiDatosAdicionales(cab.soptype, cab.sopnumbe) da
		outer apply dbo.fCfdiParametros('UTC', 'NA','NA','NA','NA','NA', 'PREDETERMINADO') p
 where cab.soptype in (3, 4)					--3 invoice, 4 return

 union all
 
 select 'en lote' estadoContabilizado, 
		cab.custnmbr idImpuestoCliente, 
		cab.TXRGNNUM,
		cab.CUSTNMBR, cab.CUSTNAME nombreCliente,
		rtrim(cab.docid) docid, cab.SOPTYPE, rtrim(cab.sopnumbe) sopnumbe, 
		cab.docdate, cab.docdate fechaHora,
		cab.ORDOCAMT total, cab.ORSUBTOT, cab.ORSUBTOT + cab.ORMRKDAM subtotal, cab.ORTAXAMT impuesto, cab.ORMRKDAM, cab.ORTDISAM, cab.ORMRKDAM + cab.ORTDISAM descuento, 
		cab.docamnt, cab.trdisamt,
		cab.orpmtrvd, rtrim(cab.curncyid) curncyid, 
		case when cab.xchgrate <= 0 then 1 else cab.xchgrate end xchgrate, 
		cab.voidStts, cab.ORDOCAMT, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.address1), 10)) address1, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.address2), 10)) address2, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.address3), 10)) address3, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.city), 10)) city, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.[STATE]), 10)) [state], 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.country), 10)) country, 
		dbo.fCfdEsVacio(dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.CCode), 10)) ccode, 
		right('00000'+dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.zipcode), 10), 5) zipcode, 
		0,
		cab.duedate, cab.pymtrmid, cab.glpostdt, 
		dbo.fCfdReemplazaSecuenciaDeEspacios(dbo.fCfdReemplazaCaracteresNI(cab.cstponbr), 10) cstponbr,
		ctrl.USRDEF05, ctrl.usrtab01, cab.commntid, ctrl.comment_1,
		cab.dex_row_id
 from  SOP10100 cab								--sop_hdr_work
		inner join vwCfdIdDocumentos id
			on id.docid = cab.DOCID
        left outer join SOP10106 ctrl			--campos def. por el usuario.
            on ctrl.SOPTYPE = cab.SOPTYPE
            and ctrl.SOPNUMBE = cab.SOPNUMBE
 where cab.SOPTYPE in (3, 4)					--3 invoice, 4 return
go

IF (@@Error = 0) PRINT 'Creación exitosa de: vwCfdiSopTransaccionesVenta'
ELSE PRINT 'Error en la creación de: vwCfdiSopTransaccionesVenta'
GO

-------------------------------------------------------------------------------------------------------

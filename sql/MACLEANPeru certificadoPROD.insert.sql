--INSTANCIA SQL PRODUCCION MEMCODB02
--Inserta datos de certificados 
--
use MPER2	--PRODUCCION
go

--Credenciales de usuario SOL
insert into cfd_CER00100 
( ID_Certificado, ruta_certificado, ruta_clave,contrasenia_clave, fecha_vig_desde, fecha_vig_hasta, estado, [fecha_ultima_modificacio], [TIME1], [usr_ultima_modificacion])
values('PAC', 'ENTHUMIN',  '', 'MacLean2016', '1/1/17', '7/24/20', 1, 0, 0, '')
go

--certificado del firmante
insert into cfd_CER00100 
( ID_Certificado, ruta_certificado, ruta_clave,contrasenia_clave, fecha_vig_desde, fecha_vig_hasta, estado, [fecha_ultima_modificacio], [TIME1], [usr_ultima_modificacion])
values('210510', '', '\\MEMCODB02\Dynshare\feMCLNPERU\feCIA\CERTEBONIFACIO_MACLEANPERU.pfx', 'LLuUD7mrKHB7cQD8', '12/12/17', '12/11/20', 1, 0, 0, '')
go

-------------------------------------------------------------------------------------
use ZPER2	--TEST
go

--Credenciales de usuario SOL
insert into cfd_CER00100 
( ID_Certificado, ruta_certificado, ruta_clave,contrasenia_clave, fecha_vig_desde, fecha_vig_hasta, estado, [fecha_ultima_modificacio], [TIME1], [usr_ultima_modificacion])
values('PAC', 'MODDATOS',  '', 'MODDATOS', '1/1/17', '7/24/20', 1, 0, 0, '')
go

--certificado del firmante
insert into cfd_CER00100 
( ID_Certificado, ruta_certificado, ruta_clave,contrasenia_clave, fecha_vig_desde, fecha_vig_hasta, estado, [fecha_ultima_modificacio], [TIME1], [usr_ultima_modificacion])
values('210510', '', '\\MEMCODB02\Dynshare\feMCLNPERUTST\feCIA\CERTEBONIFACIO_MACLEANPERU.pfx', 'LLuUD7mrKHB7cQD8', '12/12/17', '12/11/20', 1, 0, 0, '')
go

----------------------
select *
from cfd_CER00100 
where id_certificado = '210510               '

SP_COLUMNS CFD_CER00100
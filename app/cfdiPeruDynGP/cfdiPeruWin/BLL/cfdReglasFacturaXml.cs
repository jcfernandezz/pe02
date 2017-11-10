using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using System.Xml;
using System.IO;
using System.Security.AccessControl;

//using Encriptador;
using MyGeneration.dOOdads;
using cfdiPeru;
using Comun;
using Reporteador;
using MaquinaDeEstados;
using QRCodeLib;

namespace cfd.FacturaElectronica
{
    class cfdReglasFacturaXml
    {
        public string ultimoMensaje = "";
        public int numMensajeError = 0;
        private ConexionAFuenteDatos _Conexion = null;
        private Parametros _Param = null;
        CodigoDeBarras codigobb;
        Documento reporte;
        vwCfdTransaccionesDeVenta cfdiTransacciones;

        public vwCfdTransaccionesDeVenta CfdiTransacciones
        {
            get
            {
                return cfdiTransacciones;
            }

            set
            {
                cfdiTransacciones = value;
            }
        }

        public cfdReglasFacturaXml(ConexionAFuenteDatos conex, Parametros param)
        {
            _Conexion = conex;
            _Param = param;
            reporte = new Documento(_Conexion, _Param);
            codigobb = new CodigoDeBarras();

            numMensajeError = codigobb.iErr + reporte.numErr;
            ultimoMensaje = codigobb.strMensajeErr + reporte.mensajeErr;
        }

        public void AplicaFiltroADocumentos(bool filtroFecha, DateTime desdeF, DateTime hastaF, DateTime deFDefault, DateTime aFDefault,
                            bool filtroNumDoc, string numDocDe, string numDocA,
                            bool filtroIdDoc, string idDoc,
                            bool filtroEstado, string estado,
                            bool filtroCliente, string cliente, 
                            string nombreVista)
        {
            cfdiTransacciones = new vwCfdTransaccionesDeVenta(_Conexion.ConnStr, nombreVista);
            cfdiTransacciones.Query.AddOrderBy(vwCfdTransaccionesDeVenta.ColumnNames.ID_Certificado, WhereParameter.Dir.ASC);
            cfdiTransacciones.Query.AddOrderBy(vwCfdTransaccionesDeVenta.ColumnNames.Sopnumbe, WhereParameter.Dir.ASC);

            DateTime desdeFecha = new DateTime(deFDefault.Year, deFDefault.Month, deFDefault.Day, 0, 0, 0);
            DateTime hastaFecha = new DateTime(aFDefault.Year, aFDefault.Month, aFDefault.Day, 23, 59, 59);
            if (filtroFecha)
            {
                //Filtro personalizado
                desdeFecha = new DateTime(desdeF.Year, desdeF.Month, desdeF.Day, 0, 0, 0); ;
                hastaFecha = new DateTime(hastaF.Year, hastaF.Month, hastaF.Day, 23, 59, 59);
                //desdeFecha = desdeF;
                //hastaFecha = hastaF;
            }
            if ((!filtroNumDoc && !filtroIdDoc && !filtroEstado && !filtroCliente) || filtroFecha)
            {   //Filtra los documentos por fecha. De forma predeterminada es la fecha de hoy.
                cfdiTransacciones.Where.Fechahora.BetweenBeginValue = desdeFecha;
                cfdiTransacciones.Where.Fechahora.BetweenEndValue = hastaFecha;
                cfdiTransacciones.Where.Fechahora.Operator = WhereParameter.Operand.Between;
            }
            if (filtroNumDoc)
            {
                cfdiTransacciones.Where.Sopnumbe.BetweenBeginValue = numDocDe.Trim();
                cfdiTransacciones.Where.Sopnumbe.BetweenEndValue = numDocA.Trim();
                cfdiTransacciones.Where.Sopnumbe.Operator = WhereParameter.Operand.Between;
            }
            if (filtroIdDoc)
            {
                cfdiTransacciones.Where.Docid.Value = idDoc.Trim();
                cfdiTransacciones.Where.Docid.Operator = WhereParameter.Operand.Equal;
            }
            if (filtroEstado)
            {
                cfdiTransacciones.Where.Estado.Value = estado;
                cfdiTransacciones.Where.Estado.Operator = WhereParameter.Operand.Equal;
            }
            if (filtroCliente)
            {
                cfdiTransacciones.Where.NombreCliente.Value = "%" + cliente + "%";
                cfdiTransacciones.Where.NombreCliente.Operator = WhereParameter.Operand.Like;
            }
            try
            {
                if (!cfdiTransacciones.Query.Load())
                {
                    ultimoMensaje = "No hay datos para el filtro seleccionado.";
                    numMensajeError++;
                }
            }
            catch (Exception eFiltro)
            {
                ultimoMensaje = "[AplicaFiltro] Contacte al administrador. No se pudo consultar la base de datos. " + eFiltro.Message;
                numMensajeError++;
            }

        }


        public bool AplicaFiltroParaInformeMes(DateTime deFecha, DateTime aFecha,
                                            out vwCfdInformeMensualVentas infMes)
        {
            infMes = new vwCfdInformeMensualVentas(_Conexion.ConnStr);
            infMes.Query.AddOrderBy(vwCfdInformeMensualVentas.ColumnNames.Sopnumbe, WhereParameter.Dir.ASC);

            //Filtra los documentos por fecha. De forma predeterminada es la fecha de hoy.
            infMes.Where.Fechahora.BetweenBeginValue = string.Format("{0:yyyy-MM-dd}", deFecha) + " 00:00:00.0"; //"2010-08-01 00:00:00.0";
            infMes.Where.Fechahora.BetweenEndValue = string.Format("{0:yyyy-MM-dd}", aFecha) + " 23:59:59.9";
            infMes.Where.Fechahora.Operator = WhereParameter.Operand.Between;

            try
            {
                if (infMes.Query.Load())
                    return true;
                else
                    ultimoMensaje = "No hay datos para el filtro seleccionado.";
            }
            catch (Exception eFiltroMes)
            {
                ultimoMensaje = "[AplicaFiltroInformeMes] No se pudo consultar la base de datos. " + eFiltroMes.Message;
            }
            return false;
        }

        /// <summary>
        /// si la factura est� simult�neamente pagada, ingresa el cobro en el log en estado emitido
        /// </summary>
        public void RegistraLogDePagosSimultaneos(short Soptype, string Sopnumbe, string eBinarioNuevo, string eBinarioNuevoExplicado, string eBinActualConError, string eBinActualConErrorExplicado)
        {
            ultimoMensaje = "";
            numMensajeError = 0;
            vwCfdiPagosSimultaneos_wrapper pgSiml = new vwCfdiPagosSimultaneos_wrapper(_Conexion.ConnStr);
            pgSiml.Where.APTODCTY.Value = Soptype;
            pgSiml.Where.APTODCTY.Operator = WhereParameter.Operand.Equal;
            pgSiml.Where.APTODCNM.Conjuction = WhereParameter.Conj.And;
            pgSiml.Where.APTODCNM.Value = Sopnumbe;
            pgSiml.Where.APTODCNM.Operator = WhereParameter.Operand.Equal;
            try
            {
                if (pgSiml.Query.Load())
                {
                    pgSiml.Rewind();
                    for (int i = 1; i <= pgSiml.RowCount; i++)
                    {
                        RegistraLogDeArchivoXML(pgSiml.Apfrdcty, pgSiml.Apfrdcnm, pgSiml.APTODCNM, "0", _Conexion.Usuario, "", "emitido", eBinarioNuevo, eBinarioNuevoExplicado);
                    }
                }
            }
            catch (Exception eGen)
            {
                ultimoMensaje = "Excepci�n al ingresar los pagos simult�neos en el log. [RegistraLogDePagosSimultaneos] " + eGen.Message + " " + eGen.Source;
                ActualizaFacturaEmitida(Soptype, Sopnumbe, _Conexion.Usuario, "emitido", "emitido", eBinActualConError, eBinActualConErrorExplicado + ultimoMensaje.Trim());
                numMensajeError++;
                throw;
            }
        }

        /// <summary>
        /// Inserta datos de una factura en el log de facturas. 
        /// </summary>
        /// <returns></returns>
        public void RegistraLogDeArchivoXML(short soptype, string sopnumbe, string mensaje, string noAprobacion, string idusuario, string innerxml, 
                                            string eBaseNuevo, string eBinarioActual, string mensajeBinActual)
        {
            try
            {
                ultimoMensaje = "";
                numMensajeError = 0;
                //log de facturas xml emitido y xml anulado
                cfdLogFacturaXML logVenta = new cfdLogFacturaXML(_Conexion.ConnStr);
                
                logVenta.AddNew();
                logVenta.Soptype = soptype;
                logVenta.Sopnumbe = sopnumbe;
                logVenta.Mensaje = Utiles.Derecha(mensaje, 255);
                logVenta.Estado = eBaseNuevo;
                logVenta.NoAprobacion = noAprobacion;
                logVenta.FechaEmision = DateTime.Now;
                logVenta.IdUsuario = Utiles.Derecha(idusuario, 10);
                logVenta.IdUsuarioAnulacion = "-";
                logVenta.FechaAnulacion = new DateTime(1900, 1, 1);
                if (!innerxml.Equals("")) 
                    logVenta.ArchivoXML = innerxml;
                logVenta.EstadoActual = eBinarioActual;
                logVenta.MensajeEA = Utiles.Derecha(mensajeBinActual, 255);
                logVenta.Save();
           }
           catch (Exception eLog)
           {
                ultimoMensaje = "Excepci�n. No se puede ingresar el doc. " + sopnumbe+ " en la Bit�cora. [RegistraLogDeArchivoXML] " + eLog.Message + " " + eLog.Source;
                numMensajeError++;
                throw;
           }
        }

        /// <summary>
        /// Actualiza la fecha, estado y observaciones de una factura emitida en el log de facturas. 
        /// </summary>
        /// <returns></returns>
        public void ActualizaFacturaEmitida(short Soptype, string Sopnumbe, string idusuario, string eBaseAnterior, string eBaseNuevo, string eBinarioActual, string mensajeEA)
        {
            ultimoMensaje = "";
            numMensajeError = 0;
            cfdLogFacturaXML xmlEmitido = new cfdLogFacturaXML(_Conexion.ConnStr);
            xmlEmitido.Where.Soptype.Value = Soptype;
            xmlEmitido.Where.Soptype.Operator = WhereParameter.Operand.Equal;
            xmlEmitido.Where.Sopnumbe.Conjuction = WhereParameter.Conj.And;
            xmlEmitido.Where.Sopnumbe.Value = Sopnumbe;
            xmlEmitido.Where.Sopnumbe.Operator = WhereParameter.Operand.Equal;
            xmlEmitido.Where.Estado.Conjuction = WhereParameter.Conj.And;
            xmlEmitido.Where.Estado.Value = eBaseAnterior;      // "emitido";
            xmlEmitido.Where.Estado.Operator = WhereParameter.Operand.Equal;
            try
            {
                if (xmlEmitido.Query.Load())
                {
                    if (!eBaseAnterior.Equals(eBaseNuevo))
                        xmlEmitido.Estado = eBaseNuevo;         // "anulado";
                    xmlEmitido.FechaAnulacion = DateTime.Now;
                    xmlEmitido.IdUsuarioAnulacion = Utiles.Derecha(idusuario, 10);
                    xmlEmitido.EstadoActual = eBinarioActual;
                    xmlEmitido.MensajeEA = Utiles.Derecha(mensajeEA, 255);
                    xmlEmitido.Save();
                    //ultimoMensaje = "Completado.";
                }
                else
                {
                    ultimoMensaje = "No est� en la bit�cora con estado 'emitido'.";
                    numMensajeError++;
                }
            }
            catch (Exception eAnula)
            {
                ultimoMensaje = "Contacte al administrador. Error al acceder la base de datos. [ActualizaFacturaEmitida] " + eAnula.Message;
                numMensajeError++;
            }
        }

        /// <summary>
        /// Guarda el archivo xml, lo comprime en zip y anota en la bit�cora la factura emitida y el nuevo estado binario.
        /// Luego genera y guarda el c�digo de barras bidimensional y pdf. En caso de error, anota en la bit�cora. 
        /// </summary>
        /// <param name="trxVenta">Lista de facturas cuyo �ndice apunta a la factura que se va procesar.</param>
        /// <param name="comprobante">Documento xml</param>
        /// <param name="mEstados">Nuevo set de estados</param>
        /// <param name="uuid">uuid generado por el PAC</param>
        /// <returns>False cuando hay al menos un error</returns>
        public bool AlmacenaEnRepositorio(vwCfdTransaccionesDeVenta trxVenta, XmlDocument comprobante, ReglasME mEstados, String uuid, String sello)
        {   
            ultimoMensaje = "";
            numMensajeError = 0;
            try
            {   //arma el nombre del archivo xml
                string nomArchivo = Utiles.FormatoNombreArchivo(trxVenta.Docid + trxVenta.Sopnumbe + "_" + trxVenta.s_CUSTNMBR, trxVenta.s_NombreCliente, 20);
                string rutaYNomArchivo = trxVenta.RutaXml.Trim() + nomArchivo;

                //Guarda el archivo xml
                comprobante.Save(new XmlTextWriter(rutaYNomArchivo + ".xml", Encoding.UTF8));

                //Registra log de la emisi�n del xml antes de imprimir el pdf, sino habr� error al imprimir
                RegistraLogDeArchivoXML(trxVenta.Soptype, trxVenta.Sopnumbe, "Almacenado en " + rutaYNomArchivo, "0", _Conexion.Usuario, comprobante.InnerXml,
                                        "emitido", mEstados.eBinarioNuevo, mEstados.EnLetras(mEstados.eBinarioNuevo));
                
                if (numMensajeError == 0)
                {
                    RegistraLogDePagosSimultaneos(trxVenta.Soptype, trxVenta.Sopnumbe, mEstados.eBinarioNuevo, mEstados.EnLetras(mEstados.eBinarioNuevo), mEstados.eBinActualConError, mEstados.EnLetras(mEstados.eBinActualConError));

                    //Genera y guarda c�digo de barras bidimensional
                    codigobb.GenerarQRBidimensional(_Param.URLConsulta + "?&id=" + uuid.Trim() + "&re=" + trxVenta.Rfc + "&rr=" + trxVenta.IdImpuestoCliente + "&tt=" + trxVenta.Total.ToString() + "&fe=" + Utiles.Derecha(sello, 8)
                                                        , trxVenta.RutaXml.Trim() + "cbb\\" + nomArchivo + ".jpg");
                    //Genera pdf
                        if (codigobb.iErr == 0)
                            reporte.generaEnFormatoPDF(rutaYNomArchivo, trxVenta.Soptype, trxVenta.Sopnumbe, trxVenta.EstadoContabilizado);

                    //Comprime el archivo xml
                        if (_Param.zip)
                            Utiles.Zip(rutaYNomArchivo, ".xml");

                    numMensajeError = codigobb.iErr + reporte.numErr + Utiles.numErr;
                    ultimoMensaje = codigobb.strMensajeErr + " " + reporte.mensajeErr + " " + Utiles.msgErr;

                    //Si hay error en cbb o pdf o zip anota en la bit�cora
                    if (numMensajeError != 0)
                        ActualizaFacturaEmitida(trxVenta.Soptype, trxVenta.Sopnumbe, _Conexion.Usuario, "emitido", "emitido", mEstados.eBinActualConError,
                                                mEstados.EnLetras(mEstados.eBinActualConError) + ultimoMensaje.Trim());
                }
                return numMensajeError == 0;
            }
            catch (DirectoryNotFoundException)
            {
                ultimoMensaje = "Verifique la existencia de la ruta indicada en la configuraci�n de Ruta de archivos Xml. La ruta no pudo ser encontrada: " + trxVenta.RutaXml;
                numMensajeError++;
                return false;
            }
            catch (IOException)
            {
                ultimoMensaje = "Verifique permisos de escritura en: " + trxVenta.RutaXml + ". No se pudo guardar el archivo xml ni registrar el documento en la bit�cora. ";
                numMensajeError++;
                return false;
            }
            catch (Exception eAFE)
            {
                if (eAFE.Message.Contains("denied"))
                    ultimoMensaje = "Elimine el archivo xml antes de volver a generar uno nuevo. Luego vuelva a intentar. " + eAFE.Message;
                else
                    ultimoMensaje = "Contacte a su administrador. No se pudo guardar el archivo XML ni registrar la Bit�cora. " + eAFE.Message;
                numMensajeError++;
                return false;
            }
        }

        /// <summary>
        /// Genera el c�digo de barras bidimensional y guarda el archivo pdf. 
        /// Luego anota en la bit�cora la factura impresa y el nuevo estado binario
        /// 23/11/16 jcf Genera c�digo qr s�lo si par�metro emite=1
        /// </summary>
        /// <param name="trxVenta"></param>
        /// <param name="eBase"></param>
        /// <param name="eBinario"></param>
        /// <param name="enLetras"></param>
        /// <returns></returns>
        public bool AlmacenaEnRepositorio(vwCfdTransaccionesDeVenta trxVenta, string eBase, string eBinario, string enLetras)
        {
            ultimoMensaje = "";
            numMensajeError = 0;

            try
            {
                string nomArchivo = Utiles.FormatoNombreArchivo(trxVenta.Docid + trxVenta.Sopnumbe + "_" + trxVenta.s_CUSTNMBR, trxVenta.s_NombreCliente, 20);
                string rutaYNomArchivo = trxVenta.RutaXml.Trim() + nomArchivo;

                //Genera y guarda c�digo de barras bidimensional
                if(_Param.emite)
                    codigobb.GenerarQRBidimensional(_Param.URLConsulta + "?&id=" + trxVenta.UUID + "&re=" + trxVenta.Rfc + "&rr=" + trxVenta.IdImpuestoCliente + "&tt=" + trxVenta.Total.ToString() + "&fe=" + Utiles.Derecha(trxVenta.Sello, 8)
                                                , trxVenta.RutaXml.Trim() + "cbb\\" + nomArchivo + ".jpg");

                //Genera pdf
                if (codigobb.iErr == 0)
                    reporte.generaEnFormatoPDF(rutaYNomArchivo, trxVenta.Soptype, trxVenta.Sopnumbe, trxVenta.EstadoContabilizado);

                numMensajeError =  reporte.numErr + codigobb.iErr;
                ultimoMensaje = reporte.mensajeErr + codigobb.strMensajeErr;

                if (reporte.numErr==0 && codigobb.iErr==0)
                    RegistraLogDeArchivoXML(trxVenta.Soptype, trxVenta.Sopnumbe, "Almacenado en " + rutaYNomArchivo, "0", _Conexion.Usuario, "", eBase, eBinario, enLetras);

                return ultimoMensaje.Equals(string.Empty);
            }
            catch (Exception eAFE)
            {
                ultimoMensaje = "Contacte a su administrador. No se pudo guardar el archivo PDF ni registrar la Bit�cora. [AlmacenaEnRepositorio()] " + eAFE.Message;
                numMensajeError++;
                return false;
            }
        }
    }
}

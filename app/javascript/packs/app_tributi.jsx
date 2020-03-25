window.appType = "external";

import React, { useState } from 'react';
import ReactDOM from 'react-dom';
// import $ from 'jquery';
// window.jQuery = $;
// window.$ = $;

import Select from 'react-select';
import BootstrapTable from 'react-bootstrap-table-next';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCircleNotch } from '@fortawesome/free-solid-svg-icons'

function buttonFormatter(cell,row) {
  var label = "Stampa";
  if (cell.includes("aggiungi_pagamento_pagopa")) {label = "Paga con PagoPA";}
  else if(cell.includes("servizi/pagamenti")) { label = "Vai al carrello"; }
  return  <a href={cell} target="_blank" className="btn btn-default">{label}</a>;
} 

class AppTributi extends React.Component{
  dominio = window.location.protocol+"//"+window.location.hostname+(window.location.port!=""?":"+window.location.port:"");
  numeroAnni = $("#numero_anni").text();
  columns = {
    tari: {
      immobili: [
        { dataField: "indirizzo", text: "Indirizzo" },
        { dataField: "catasto", text: "Catasto" },
        { dataField: "categoria", text: "Categoria" },
        { dataField: "tipoTariffa", text: "Tipo tariffa" },
        { dataField: "mq", text: "Mq" },
        { dataField: "riduzioniApplicate", text: "Riduzioni applicate" },
        { dataField: "validita", text: "Validità" },
      ],
      pagamenti: [
        { dataField: "descrizioneAvviso", text: "Descrizione avviso" },
        { dataField: "importoEmesso", text: "Importo emesso" },
        { dataField: "importoPagato", text: "Importo pagato" },
        { dataField: "importoResiduo", text: "Importo da pagare" },
        /*{ dataField: "azioni", text: "Azioni", formatter: buttonFormatter },*/ // commentato fino al 2020
      ],      
    },
    imutasi: {
      immobili: [
        { dataField: "indirizzo", text: "Indirizzo" },
        { dataField: "catasto", text: "Catasto" },
        { dataField: "categoria", text: "Categoria" },
        { dataField: "rendita", text: "Rendita" },
        { dataField: "possesso", text: "Titolo di possesso" },
        { dataField: "riduzioni", text: "Riduzioni applicate" },
        { dataField: "aliquota", text: "Aliquota" },
        { dataField: "validita", text: "Validità" },
      ], 
      pagamenti: [
        { dataField: "anno", text: "Anno" },
        { dataField: "rata", text: "Rata" },
        { dataField: "importoDovuto", text: "Importo dovuto" },
        { dataField: "importoVersato", text: "Importo versato" },
        { dataField: "totaleImportoDovuto", text: "Totale dovuto" },
        { dataField: "numeroImmobili", text: "N. immobili" },
        { dataField: "azioni", text: "Azioni", formatter: buttonFormatter },
      ],    
    },    
    versamenti: [
      { dataField: "imposta", text: "Imposta" },
      { dataField: "dataVersamento", text: "Data versamento" },
      { dataField: "tipo", text: "Tipo" },
      { dataField: "annoRiferimento", text: "Anno riferimento" },
      { dataField: "codiceTributo", text: "Codice tributo" },
      { dataField: "rata", text: "Rata" },
      { dataField: "detrazione", text: "Detrazione" },
      { dataField: "totale", text: "Totale" },
      { dataField: "ravvedimento", text: "Ravvedimento" },
      { dataField: "violazione", text: "Violazione" },
    ]
  };
  tables = { };
  state = {
    identificativoSoggetto:false,
    token:false,
    tari: {},
    imu: {},
    tasi: {}
  }
  constructor(props){
    super(props);
    
    this.selectAnni = React.createRef();
    this.annoCorrente = new Date().getFullYear();
    this.state.selected = { value: this.annoCorrente, label: this.annoCorrente };
    
    this.authenticate();
  }
  
  componentDidUpdate(prevProps, prevState, snapshot) {
    
    console.log("AppTributi did update");
    $("table.table-responsive").each(function(){
      var id = $(this).attr("id");
      if(typeof(tableToUl) === "function" && typeof($('li.table-header').css("font-weight"))!="undefined") {
        console.log("Calling tableToUl on "+id);
        tableToUl($("#"+id));
      } else  { console.log("tableToUl is not a function ("+typeof(tableToUl)+") or no css available for responsive tables"); } 
    });
  }
  
  componentDidMount() {
//     var $yearDropdown = $("#yearSelect");
//     $yearDropdown.on('change', this.changeYear);
  }
  
  authenticate() {
    console.log("dominio: "+this.dominio);
    var self = this;
    console.log("Authenticating on "+this.dominio+"/authenticate...");
    $.get(this.dominio+"/authenticate").done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
      } else {
        self.getIdentificativo();
      }
    }).fail(function(response) {
      console.log("authentication fail!");
      console.log(response);
    });
  } 
  
  getIdentificativo() {
    var self = this;
    console.log("Getting identificativo...");
    $.get(this.dominio+"/soggetto", {data:{anno:this.state.selected.value}}).done(function( response ) {
      console.log("identificativo response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
	console.log("response result is");
        console.log(response.result);
        var state = self.state;
        state.identificativoSoggetto = response.result;
        self.setState(state);

	if(response.result!=null) {
          console.log("result not null, fetching other data");
          self.setState(state);
          self.getImmobiliTARI();
          self.getPagamentiTARI();
          self.getImmobiliIMUTASI();
          self.getVersamenti();
          self.getPagamentiIMUTASI();
        }
      }
    }).fail(function(response) {
      console.log("identificativo fail!");
      console.log(response);
    });
  }
  
  getImmobiliTARI() {
    var self = this;
    console.log("Getting immobili tari...");
    $.get(this.dominio+"/tari_immobili", {data:{anno:this.state.selected.value}}).done(function( response ) {
      console.log("immobili tari response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.tari.immobili = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("immobili tari fail!");
      console.log(response);
    });
  }
  
  getPagamentiTARI() {
    var self = this;
    console.log("Getting pagamenti tari...");
    $.get(this.dominio+"/tari_pagamenti", {data:{anno:this.state.selected.value}}).done(function( response ) {
      console.log("pagamenti tari response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.tari.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti tari fail!");
      console.log(response);
    });
  }
  
  getImmobiliIMUTASI() {
    var self = this;
    console.log("Getting immobili imutasi...");
    $.get(this.dominio+"/imutasi_immobili", {data:{anno:this.state.selected.value}}).done(function( response ) {
      console.log("imutasi response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.imu.immobili = response.imu;
        state.tasi.immobili = response.tasi;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("immobili imutasi fail!");
      console.log(response);
    });
  }
  
  getVersamenti() {
    var self = this;
    console.log("Getting versamenti...");
    $.get(this.dominio+"/versamenti", {data:{}}).done(function( response ) {
      console.log("versamenti response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.versamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("versamenti fail!");
      console.log(response);
    });
  }
  
  getPagamentiIMUTASI() {
    var self = this;
    var today = new Date();
    var dd = String(today.getDate()).padStart(2, '0');
    var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
    var yyyy = today.getFullYear();

//     today = encodeURI(mm + '/' + dd + '/' + yyyy); // prod
    today = encodeURI(yyyy + '-' + mm + '-' + dd); // test
    console.log("Getting pagamenti imutasi ("+today+")...");
    $.get(this.dominio+"/imutasi_pagamenti", {data:{dataPagamento:today,modulo:"Imposta_Immobili"}}).done(function( response ) {
      console.log("pagamenti imu response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        /*for (var i in response.tabella) {
          if(response.tabella[i].totaleImportoDovuto == 0){delete response.tabella[i];}
        }*/
        state.imu.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti fail!");
      console.log(response);
    });
    $.get(this.dominio+"/imutasi_pagamenti", {data:{dataPagamento:today,modulo:"Tassa_Servizi"}}).done(function( response ) {
      console.log("pagamenti tasi response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        /*for (var i in response.tabella) {
          if(response.tabella[i].totaleImportoDovuto == 0){delete response.tabella[i];}
        }*/
        state.tasi.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti fail!");
      console.log(response);
    });
  }
  
  changeYear = (selectedYear) =>  {
//     var selectedYear = event.target.value
    var state = this.state;
    state.selectedYear = selectedYear;
    delete state.tari.immobili;
    delete state.imu.immobili;
    delete state.tasi.immobili;
    //delete state.identificativoSoggetto;
    this.setState(state);
    console.log(this.state);
    this.getIdentificativo();
    this.getImmobiliTARI();
    this.getImmobiliIMUTASI();
  };
  
  render(){
    console.log("rendering app tributi");
    const { selectedYear } = this.state.selected.value;
    var options = [];
    
    for(var i = this.annoCorrente; i>=2012; i--){
      options.push({ value: i, label: i });
//       options.push(<option key={i} value={i} >{i}</option>);
//       options.push(i);
    }

    var returnVal = <div className="alert alert-warning">Dati contribuente non presenti nel sistema</div>
    if(this.state.identificativoSoggetto!=null) {
      returnVal =       <div itemID="app_tributi">
        <h4>Dati contribuente</h4>
        {this.state.identificativoSoggetto?
          <ul>
            <li><strong>Cognome:</strong> {this.state.identificativoSoggetto.cognome}</li>
            <li><strong>Nome:</strong> {this.state.identificativoSoggetto.nome}</li>
            <li><strong>CF:</strong> {this.state.identificativoSoggetto.codiceFiscale}</li>
          </ul>:<p>Caricamento dati utente...</p>
        }   
        
        <p></p>
          
        <ul className="nav nav-tabs">
          <li role="presentation" className="active"><a href="#immobili" aria-controls="immobili" role="tab" data-toggle="immobili">Situazione annuale </a></li>
          <li role="presentation"><a href="#pagamenti" aria-controls="pagamenti" role="tab" data-toggle="pagamenti">Versamenti</a></li>
          <li role="presentation"><a href="#ravvedimenti" aria-controls="ravvedimenti" role="tab" data-toggle="ravvedimenti">Da pagare</a></li>
        </ul>
        
        <div className="tab-content">
        
          <div role="tabpanel" className="tab-pane" id="immobili">
            <h3>Situazione immobili per l'anno <div style={{width: '128px', display: 'inline-block'}}><Select options={options} onChange={this.changeYear} defaultValue={this.state.selected} /></div></h3>
            <h4>TARI - Tassa Rifiuti</h4>
            {typeof(this.state.tari.immobili) == "undefined" ? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> : this.state.tari.immobili.length>0 ? <BootstrapTable
                id="immobiliTari"
                keyField={"indirizzo"}
                data={this.state.tari.immobili}
                columns={this.columns.tari.immobili}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Nessun risultato per l'anno scelto</p> }
            <h4>IMU - Imposta sugli Immobili</h4>
            {typeof(this.state.imu.immobili) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.imu.immobili.length>0 ? <BootstrapTable
                id="immobiliImu"
                keyField={"id"}
                data={this.state.imu.immobili}
                columns={this.columns.imutasi.immobili}
                classes="table-responsive"
                striped
                hover
              />  : <p className="text-center">Nessun risultato per l'anno scelto</p> }
            <h4>TASI - Tributo Servizi Indivisibili</h4>
            {typeof(this.state.tasi.immobili) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.tasi.immobili.length>0 ? <BootstrapTable
                id="immobiliTasi"
                keyField={"id"}
                data={this.state.tasi.immobili}
                columns={this.columns.imutasi.immobili}
                classes="table-responsive"
                striped
                hover
              />  : <p className="text-center">Nessun risultato per l'anno scelto</p> }
          </div>
          
          <div role="tabpanel" className="tab-pane" id="pagamenti">
            <h3>Elenco versamenti per gli anni 2012 - {this.annoCorrente}</h3>
            {typeof(this.state.versamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.versamenti.length>0 ? <BootstrapTable
                id="versamenti"
                keyField={"totale"}
                data={this.state.versamenti}
                columns={this.columns.versamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Nessun risultato per gli anni 2012 - {this.annoCorrente}</p> }
          </div>
          
          <div role="tabpanel" className="tab-pane" id="ravvedimenti">
            <h3>Elenco pagamenti in sospeso per gli anni {this.annoCorrente-this.numeroAnni} - {this.annoCorrente}</h3>
            <h4>TARI - Tassa Rifiuti</h4>
            {typeof(this.state.tari.pagamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> : this.state.tari.pagamenti.length>0 ? <BootstrapTable
                id="pagamentiTari"
                keyField={"descrizioneAvviso"}
                data={this.state.tari.pagamenti}
                columns={this.columns.tari.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-this.numeroAnni} - {this.annoCorrente}</p> }
            <h4>IMU - Imposta sugli Immobili</h4>
            {typeof(this.state.imu.pagamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.imu.pagamenti.tabella.length>0 ? <BootstrapTable
                id="pagamentiImu"
                keyField={"azioni"}
                data={this.state.imu.pagamenti.tabella}
                columns={this.columns.imutasi.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-this.numeroAnni} - {this.annoCorrente}</p> }       
            <h4>TASI - Tributo Servizi Indivisibili</h4>
            {typeof(this.state.tasi.pagamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.tasi.pagamenti.tabella.length>0 ? <BootstrapTable
                id="pagamentiTasi"
                keyField={"azioni"}
                data={this.state.tasi.pagamenti.tabella}
                columns={this.columns.imutasi.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-this.numeroAnni} - {this.annoCorrente}</p> }      
          </div>
        
        </div>
      </div>     
    }
    
    return(returnVal);
  }

}


if(document.getElementById('app_tributi_container') !== null){
  ReactDOM.render(<AppTributi />, document.getElementById('app_tributi_container') );
  var $links = $("#topbar").find(".row");
  $links.find("div").last().remove();
  $links.find("div").first().removeClass("col-lg-offset-3").removeClass("col-md-offset-3");
  $links.append('<div class="col-lg-2 col-md-2 text-center"><a href="'+$("#dominio_portale").text()+'/" title="Sezione Privata">CIAO<br>'+$("#nome").text()+'</a></div>');
  $links.append('<div class="col-lg-1 col-md-1 logout_link"><a href="'+$("#dominio_portale").text()+'/autenticazione/logout" title="Logout"><span class="glyphicon glyphicon-log-out" aria-hidden="true"></span></a></div>');
  $(".tab-pane").hide();  
  
  $("#immobili").show();
  
  $('.nav-tabs a').on('click',function (e) {
    e.preventDefault();
    $(".tab-pane").hide();
    $(".nav-tabs li").removeClass("active");
    $("#"+$(this).data("toggle")).show()
    $(this).parent().addClass("active");
  })
}

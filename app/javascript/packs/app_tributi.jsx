//http://api.civilianextdev.it/tributi/api/help/doc/index#!/Utilities/Utilities_AuthenticationToken

/*
 
{
"targetResource": "http://api.civilianextdev.it",
"tenantId": "6296a508-1cf0-4210-a27b-4abaa2151193",
"clientId" :"01c271b4-da93-4bf0-a5cc-e7a1b1b107b9",
"secret":"JXDnrWwklQpS9TTTJMUxSMCh4pPoAyRL9wNBrlzWtxs="
} 

 */

import React from 'react'
import ReactDOM from 'react-dom'
import Select from 'react-select';
import $ from 'jquery';
window.jQuery = $;
window.$ = $;
import BootstrapTable from 'react-bootstrap-table-next';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCircleNotch } from '@fortawesome/free-solid-svg-icons'

var cf = 'SMNNGL67D24D644Y';
// var cf = 'ZZISNT46H66D644A';
// var anno = 2017;

$(document).ready(function(){
  var $div = $("<div>");
  $("body").append($div);
  ReactDOM.render(<AppTributi />, $div[0] );
});


class AppTributi extends React.Component{
  columns = {
    tasi: {
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
      ],      
    },
    imu: {
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
        { dataField: "dataVersamento", text: "Data versamento" },
        { dataField: "annoRiferimento", text: "Anno riferimento" },
        { dataField: "codiceTributo", text: "Codice tributo" },
        { dataField: "acconto", text: "Acconto" },
        { dataField: "saldo", text: "Saldo" },
        { dataField: "detrazione", text: "Detrazione" },
        { dataField: "totale", text: "Totale" },
        { dataField: "ravvedimento", text: "Ravvedimento" },
        { dataField: "violazione", text: "Violazione" },
      ],  
      ravvedimento: [
        { dataField: "codiceTributo", text: "Codice tributo" },
        { dataField: "rata", text: "Rata" },
        { dataField: "importoVersato", text: "Importo versato" },
        { dataField: "totaleImportoDovuto", text: "Totale dovuto" },
        { dataField: "numeroImmobili", text: "N. immobili" },
      ],    
    }
  };
  tables = { };
  state = {
    identificativoSoggetto:false,
    token:false,
    tasi: {},
    imu: {}
  }
  constructor(props){
    super(props);
    
    this.auth = {
      "targetResource": "http://api.civilianextdev.it",
      "tenantId": "6296a508-1cf0-4210-a27b-4abaa2151193",
      "clientId" :"01c271b4-da93-4bf0-a5cc-e7a1b1b107b9",
      "secret":"JXDnrWwklQpS9TTTJMUxSMCh4pPoAyRL9wNBrlzWtxs="
    };
    
    this.selectAnni = React.createRef();
    this.annoCorrente = new Date().getFullYear();
    this.state.options = {selectedYear: { value: this.annoCorrente, label: this.annoCorrente }};
    
    this.authenticate();
  }
  
  componentDidUpdate(prevProps, prevState, snapshot) {
    console.log("AppTributi did update.");
    console.log(this.state.tasi);
  }
  
  authenticate() {
    var self = this;
    console.log("Authenticating...");
    $.get("http://localhost:3000/authenticate", {data:this.auth}).done(function( response ) {
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
    $.get("http://localhost:3000/soggetto", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.identificativoSoggetto = response.result;
        self.setState(state);
        self.getImmobiliTASI();
        self.getPagamentiTASI();
        self.getImmobiliIMU();
        self.getPagamentiIMU();
        self.getRavvedimentoIMU();
      }
    }).fail(function(response) {
      console.log("identificativo fail!");
      console.log(response);
    });
  }
  
  getImmobiliTASI() {
    var self = this;
    console.log("Getting immobili tasi...");
    $.get("http://localhost:3000/tasi_immobili", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.tasi.immobili = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("immobili tasi fail!");
      console.log(response);
    });
  }
  
  getPagamentiTASI() {
    var self = this;
    console.log("Getting pagamenti tasi...");
    $.get("http://localhost:3000/tasi_pagamenti", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.tasi.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti tasi fail!");
      console.log(response);
    });
  }
  
  getImmobiliIMU() {
    var self = this;
    console.log("Getting immobili imu...");
    $.get("http://localhost:3000/imu_immobili", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.imu.immobili = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("immobili imu fail!");
      console.log(response);
    });
  }
  
  getPagamentiIMU() {
    var self = this;
    console.log("Getting pagamenti imu...");
    $.get("http://localhost:3000/imu_pagamenti", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.imu.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti imu fail!");
      console.log(response);
    });
  }
  
  getRavvedimentoIMU() {
    var self = this;
    var today = new Date();
    var dd = String(today.getDate()).padStart(2, '0');
    var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
    var yyyy = today.getFullYear();

    today = mm + '/' + dd + '/' + yyyy;
    console.log("Getting ravvedimento imu...");
    $.get("http://localhost:3000/imu_ravvedimento", {data:{anno:this.state.options.selectedYear.value,dataPagamento:today}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.imu.ravvedimento = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("ravvedimento fail!");
      console.log(response);
    });
  }
  
  getLinkStampa() {
    var self = this;
    console.log("Getting linkStampa imu...");
    $.get("http://localhost:3000/stampa_f24", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
      console.log("response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.imu.linkStampa = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("fail!");
      console.log(response);
    });
  }
  
  changeYear = selectedYear => {
    console.log(`Year has changed:`, selectedYear);
//     this.setState({options:{ selectedYear }});
//     this.setState({options:{ selectedYear }, imu:{pagamenti:this.state.imu.pagamenti}, tasi:{}});
    this.state.options.selectedYear = selectedYear;
    this.setState({imu:{pagamenti:this.state.imu.pagamenti}, tasi:{}});
    console.log(this.state);
    this.getImmobiliTASI();
    this.getPagamentiTASI();
    this.getImmobiliIMU();
    this.getRavvedimentoIMU();
  };
  
  render(){
    console.log("rendering app tributi");
    const { selectedYear } = this.state.options;
    var options = [];
    
    for(var i = this.annoCorrente; i>=2012; i--){
      options.push({ value: i, label: i });
    }
    
    return(
      <div itemID="app_tributi">
        <h3>Dati contribuente</h3>
        {this.state.identificativoSoggetto?
          <ul>
            <li><strong>Cognome:</strong> {this.state.identificativoSoggetto.cognome}</li>
            <li><strong>Nome:</strong> {this.state.identificativoSoggetto.nome}</li>
            <li><strong>CF:</strong> {this.state.identificativoSoggetto.codiceFiscale}</li>
          </ul>:<p>Caricamento dati utente...</p>
        }
        Anno: <Select options={options} value={selectedYear} onChange={this.changeYear} />
        <h3>TASI</h3>
        <h4>Immobili</h4>
        {typeof(this.state.tasi.immobili) == "undefined" ? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> : this.state.tasi.immobili.length>0 ? <BootstrapTable
            keyField={"indirizzo"}
            data={this.state.tasi.immobili}
            columns={this.columns.tasi.immobili}
            classes="table-responsive"
            striped
            hover
          /> : <p class="text-center">Nessun risultato per l'anno scelto</p> }
        <h4>Pagamenti</h4>
        {typeof(this.state.tasi.pagamenti) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> : this.state.tasi.pagamenti.length>0 ? <BootstrapTable
            keyField={"descrizioneAvviso"}
            data={this.state.tasi.pagamenti}
            columns={this.columns.tasi.pagamenti}
            classes="table-responsive"
            striped
            hover
          /> : <p class="text-center">Nessun risultato per l'anno scelto</p> }
        <h3>IMU</h3>
        <h4>Immobili</h4>
        {typeof(this.state.imu.immobili) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.imu.immobili.length>0 ? <BootstrapTable
            keyField={"validita"}
            data={this.state.imu.immobili}
            columns={this.columns.imu.immobili}
            classes="table-responsive"
            striped
            hover
          />  : <p class="text-center">Nessun risultato per l'anno scelto</p> }
        <h4>Pagamenti</h4>
        {typeof(this.state.imu.pagamenti) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.imu.pagamenti.length>0 ? <BootstrapTable
            keyField={"totale"}
            data={this.state.imu.pagamenti}
            columns={this.columns.imu.pagamenti}
            classes="table-responsive"
            striped
            hover
          /> : <p class="text-center">Nessun risultato per gli anni 2012 - {this.annoCorrente}</p> }
        <h4>Ravvedimento</h4>
        {typeof(this.state.imu.ravvedimento) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.imu.ravvedimento.tabella.length>0 ? <BootstrapTable
            keyField={"totaleImportoDovuto"}
            data={this.state.imu.ravvedimento.tabella}
            columns={this.columns.imu.ravvedimento}
            classes="table-responsive"
            striped
            hover
          /> : <p class="text-center">Tutti i pagamenti risultano in regola per l'anno scelto</p> }
          
        {typeof(this.state.imu.ravvedimento) != "undefined" && this.state.imu.ravvedimento.tabella.length>0? <p><a class="btn btn-default" href={this.state.imu.ravvedimento.urls.acconto} target="_parent">Stampa F24 ravvedimento (acconto)</a> <a class="btn btn-default" href={this.state.imu.ravvedimento.urls.saldo} target="_parent">Stampa F24 ravvedimento (saldo)</a></p> : '' }
      </div>
    );
  }
}

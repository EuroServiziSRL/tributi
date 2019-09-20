import React from 'react'
import ReactDOM from 'react-dom'
import Select from 'react-select';
import $ from 'jquery';
window.jQuery = $;
window.$ = $;
import BootstrapTable from 'react-bootstrap-table-next';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCircleNotch } from '@fortawesome/free-solid-svg-icons'

// var cf = 'SMNNGL67D24D644Y';
// var cf = 'ZZISNT46H66D644A';
// var anno = 2017;

$(document).ready(function(){
  $(".tab-pane").hide();
  var $div = $("<div>");
  $("#portal_container").append($div);
  ReactDOM.render(<AppTributi />, $div[0] );
  
  $("#immobili").show();
  
  $('.nav-tabs a').on('click',function (e) {
    e.preventDefault();
    $(".tab-pane").hide();
    $(".nav-tabs li").removeClass("active");
    $("#"+$(this).data("toggle")).show()
    $(this).parent().addClass("active");
  })
});

function buttonFormatter(cell,row) {
  var label = "Stampa";
  console.log(cell);
  if (cell.includes("aggiungi_pagamento_pagopa")) {label = "Paga con PagoPA";}
  else if(cell.includes("servizi/pagamenti")) { label = "Vai al carrello"; }
  return  <a href={cell} class="btn btn-default">{label}</a>;
} 

class AppTributi extends React.Component{
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
        { dataField: "azioni", text: "Azioni", formatter: buttonFormatter },
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
        { dataField: "totaleImportoDovuto", text: "Totale dovuto" },
        { dataField: "importoVersato", text: "Importo versato" },
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
      { dataField: "acconto", text: "Acconto" },
      { dataField: "saldo", text: "Saldo" },
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
    
//     this.auth = {
//       "targetResource": "http://api.civilianextdev.it", // API URL è in application controller!!!
//       "tenantId": "6296a508-1cf0-4210-a27b-4abaa2151193",
//       "clientId" :"01c271b4-da93-4bf0-a5cc-e7a1b1b107b9",
//       "secret":"JXDnrWwklQpS9TTTJMUxSMCh4pPoAyRL9wNBrlzWtxs="
//     };
/*    this.auth = {
      "targetResource": "http://api.civilianext.it",
      "tenantId": "1c46d27e-fa3c-4ad4-a1cc-410d55d2feb8",
      "clientId" :"8071e7a8-6423-48a2-a208-b6d16e86fdad",
      "secret":"MGGbYjQHFqnee48TJRffvYEJY+XgmXZv5xNa0Tz7e5E="
    }; */ 

// piovene rocchette
    this.auth = {
      "targetResource": "http://api.civilianext.it", // API URL è in application controller!!!
      "tenantId": "1c46d27e-fa3c-4ad4-a1cc-410d55d2feb8",
      "clientId" :"2b1cfbdc-decc-45a2-a215-8a4179ab79f7",
      "secret":"g*Q[Azfhd_u=Cnrmvl6uaNkxvpxzn184"
    };


// ascoli piceno
//     this.auth = {
//       "targetResource": "http://api.civilianext.it", // API URL è in application controller!!!
//       "tenantId": "9115f769-3f1d-485c-891e-b9eb578e2ca6",
//       "clientId" :"8f9b3b9a-b821-459f-baef-e3087a320a48",
//       "secret":"ww8-649ng.US.nZ*nT]1L49V@0SwrYy+"
//     };

    this.selectAnni = React.createRef();
    this.annoCorrente = new Date().getFullYear();
    this.state.options = {selectedYear: { value: this.annoCorrente, label: this.annoCorrente }};
    
    this.authenticate();
  }
  
  componentDidUpdate(prevProps, prevState, snapshot) {
    console.log("AppTributi did update.");
    console.log(this.state.tari);
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
      console.log("identificativo response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.identificativoSoggetto = response.result;
        self.setState(state);
        self.getImmobiliTARI();
        self.getPagamentiTARI();
        self.getImmobiliIMUTASI();
        self.getVersamenti();
        self.getPagamentiIMUTASI();
      }
    }).fail(function(response) {
      console.log("identificativo fail!");
      console.log(response);
    });
  }
  
  getImmobiliTARI() {
    var self = this;
    console.log("Getting immobili tari...");
    $.get("http://localhost:3000/tari_immobili", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
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
    $.get("http://localhost:3000/tari_pagamenti", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
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
    $.get("http://localhost:3000/imutasi_immobili", {data:{anno:this.state.options.selectedYear.value}}).done(function( response ) {
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
    $.get("http://localhost:3000/versamenti", {data:{}}).done(function( response ) {
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
    $.get("http://localhost:3000/imutasi_pagamenti", {data:{dataPagamento:today,modulo:"Imposta_Immobili"}}).done(function( response ) {
      console.log("pagamenti imu response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.imu.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti fail!");
      console.log(response);
    });
    $.get("http://localhost:3000/imutasi_pagamenti", {data:{dataPagamento:today,modulo:"Tassa_Servizi"}}).done(function( response ) {
      console.log("pagamenti tasi response is loaded");
      console.log(response);
      if(response.hasError) {
        console.log("response error");
      } else {
        var state = self.state;
        state.tasi.pagamenti = response;
        self.setState(state);
      }
    }).fail(function(response) {
      console.log("pagamenti fail!");
      console.log(response);
    });
  }
  
  changeYear = selectedYear => {
    console.log(`Year has changed:`, selectedYear);
//     this.setState({options:{ selectedYear }});
//     this.setState({options:{ selectedYear }, imu:{pagamenti:this.state.versamenti}, tari:{}});
//     this.state.options.selectedYear = selectedYear;
    var state = this.state;
    state.options.selectedYear = selectedYear;
    delete state.tari.immobili;
    delete state.imu.immobili;
    delete state.identificativoSoggetto;
    this.setState(state);
//     this.setState({imu:{pagamenti:this.state.versamenti}, tari:{}});
//     console.log(this.state);
    this.getIdentificativo();
    this.getImmobiliTARI();
//     this.getPagamentiTARI();
    this.getImmobiliIMUTASI();
//     this.getPagamentiIMUTASI();
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
        <h4>Dati contribuente</h4>
        {this.state.identificativoSoggetto?
          <ul>
            <li><strong>Cognome:</strong> {this.state.identificativoSoggetto.cognome}</li>
            <li><strong>Nome:</strong> {this.state.identificativoSoggetto.nome}</li>
            <li><strong>CF:</strong> {this.state.identificativoSoggetto.codiceFiscale}</li>
          </ul>:<p>Caricamento dati utente...</p>
        }   
        
        <p></p>
          
        <ul class="nav nav-tabs">
          <li role="presentation" class="active"><a href="#immobili" aria-controls="immobili" role="tab" data-toggle="immobili">Situazione annuale </a></li>
          <li role="presentation"><a href="#pagamenti" aria-controls="pagamenti" role="tab" data-toggle="pagamenti">Versamenti</a></li>
          <li role="presentation"><a href="#ravvedimenti" aria-controls="ravvedimenti" role="tab" data-toggle="ravvedimenti">Da pagare</a></li>
        </ul>
        
        <div class="tab-content">
        
          <div role="tabpanel" class="tab-pane" id="immobili">
            <h3>Situazione immobili per l'anno <div style={{width: '128px', display: 'inline-block'}}><Select options={options} value={selectedYear} onChange={this.changeYear} /></div></h3>
            <h4>TARI - Tassa Rifiuti</h4>
            {typeof(this.state.tari.immobili) == "undefined" ? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> : this.state.tari.immobili.length>0 ? <BootstrapTable
                keyField={"indirizzo"}
                data={this.state.tari.immobili}
                columns={this.columns.tari.immobili}
                classes="table-responsive"
                striped
                hover
              /> : <p class="text-center">Nessun risultato per l'anno scelto</p> }
            <h4>IMU - Imposta sugli Immobili</h4>
            {typeof(this.state.imu.immobili) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.imu.immobili.length>0 ? <BootstrapTable
                keyField={"validita"}
                data={this.state.imu.immobili}
                columns={this.columns.imutasi.immobili}
                classes="table-responsive"
                striped
                hover
              />  : <p class="text-center">Nessun risultato per l'anno scelto</p> }
            <h4>TASI - Tributo Servizi Indivisibili</h4>
            {typeof(this.state.tasi.immobili) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.tasi.immobili.length>0 ? <BootstrapTable
                keyField={"validita"}
                data={this.state.tasi.immobili}
                columns={this.columns.imutasi.immobili}
                classes="table-responsive"
                striped
                hover
              />  : <p class="text-center">Nessun risultato per l'anno scelto</p> }
          </div>
          
          <div role="tabpanel" class="tab-pane" id="pagamenti">
            <h3>Elenco versamenti per gli anni 2012 - {this.annoCorrente}</h3>
            {typeof(this.state.versamenti) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.versamenti.length>0 ? <BootstrapTable
                keyField={"totale"}
                data={this.state.versamenti}
                columns={this.columns.versamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p class="text-center">Nessun risultato per gli anni 2012 - {this.annoCorrente}</p> }
          </div>
          
          <div role="tabpanel" class="tab-pane" id="ravvedimenti">
            <h3>Elenco pagamenti in sospeso per gli anni {this.annoCorrente-3} - {this.annoCorrente}</h3>
            <h4>TARI - Tassa Rifiuti</h4>
            {typeof(this.state.tari.pagamenti) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> : this.state.tari.pagamenti.length>0 ? <BootstrapTable
                keyField={"descrizioneAvviso"}
                data={this.state.tari.pagamenti}
                columns={this.columns.tari.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p class="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-3} - {this.annoCorrente}</p> }
            <h4>IMU - Imposta sugli Immobili</h4>
            {typeof(this.state.imu.pagamenti) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.imu.pagamenti.tabella.length>0 ? <BootstrapTable
                keyField={"azioni"}
                data={this.state.imu.pagamenti.tabella}
                columns={this.columns.imutasi.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p class="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-3} - {this.annoCorrente}</p> }       
            <h4>TASI - Tributo Servizi Indivisibili</h4>
            {typeof(this.state.tasi.pagamenti) == "undefined"? <p class="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span class="sr-only">caricamento...</span></p> :this.state.tasi.pagamenti.tabella.length>0 ? <BootstrapTable
                keyField={"azioni"}
                data={this.state.tasi.pagamenti.tabella}
                columns={this.columns.imutasi.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p class="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-3} - {this.annoCorrente}</p> }      
          </div>
        
        </div>
      </div>
    );
  }

}

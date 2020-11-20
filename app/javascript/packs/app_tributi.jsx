window.appType = "external";

import React, { useState } from 'react';
import ReactDOM from 'react-dom';
// import $ from 'jquery';
// window.jQuery = $;
// window.$ = $;

import Select from 'react-select';
import BootstrapTable from 'react-bootstrap-table-next';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faCircleNotch,faCheck } from '@fortawesome/free-solid-svg-icons'

function buttonFormatter(cell,row) {
  var label = "Stampa";
  if (cell.includes("aggiungi_pagamento_pagopa")) {label = "Paga con PagoPA";}
  else if(cell.includes("servizi/pagamenti")) { label = "Vai al carrello"; }
  return  <a href={cell} target="_blank" className="btn btn-primary">{label}</a>;
}

function pad(n) {return n < 10 ? "0"+n : n;}

function dateFormatter(cell, row) {
  var formatted = cell;
  if(cell && cell.match(/\d{4}\-\d{2}\-\d{2}T\d{2}:\d{2}:\d{2}/g)) {
    var dateString = cell.replace(/-/g,"/").replace(/T.*/g," ").replace(/\.\d{3}Z/g,"");
    // console.log("cell",cell,"dateString",dateString);
    var date = new Date(dateString);
    formatted =  pad(date.getDate())+"/"+pad(date.getMonth()+1)+"/"+date.getFullYear();
  } else {
    // console.log("cell",cell);
  }
  return <>{formatted}</>;
} 

function booleanFormatter(cell, row) {
  var returnString = cell
  var yes = undefined;
  if(typeof(cell)=="boolean") {
    yes = cell;
  } else if (typeof(cell)!="undefined" && ['sì', 'true', 'si', '1'].indexOf(cell.toLowerCase()) >= 0) {
    yes = true;
  } else if(typeof(cell)!="undefined" && ['no', 'false', '0'].indexOf(cell.toLowerCase()) >= 0) {
    yes = false;
  }
  if(typeof(yes)!="undefined") {
    returnString = yes?<FontAwesomeIcon icon={faCheck} />:<></>
  }
  return returnString;
}


function numberFormatter(cell, row) {
  // console.log(cell);
  var formatted = cell;
  if(!isNaN(cell)) {
    try {
      formatted = Number(cell).toLocaleString('it', { minimumFractionDigits: 2 })
    } catch(e) {
      // ignore errors
    }
  }
  return <span>{formatted}&euro;</span>;
}

function htmlFormatter(cell,row) {
  return <span dangerouslySetInnerHTML={ {__html: cell} }></span>
}

function ucfirst(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

function sortResponsiveTable($table, columnIndex, sortings) {
  console.log("called sort on column",columnIndex);
  for(var sorting of sortings) {
    console.log("sorting by",sorting.column, sorting.order?"ASC":"DESC");
  }
  $table.find("li:not(.table-header)").sort((a, b) => {
    var valueA = $($(a).find("div")[columnIndex]).text().replace(/^[^:]+:/,"");
    var valueB = $($(b).find("div")[columnIndex]).text().replace(/^[^:]+:/,"");
    var returnValue = 0;
    for(var sorting of sortings) {
      if (valueA === valueB) {
        // skip to next sorting
      } else {
        if(sorting.order===true) {
          returnValue = valueA < valueB?-1:1;
        } else {
          returnValue = valueB < valueA?-1:1;
        }
        break;
      }
    }   
    return returnValue;                 
  }).appendTo($table);
  console.log("called sort on column",columnIndex);
}

class AppTributi extends React.Component{
  dominio = window.location.protocol+"//"+window.location.hostname+(window.location.port!=""?":"+window.location.port:"");
  anniSituazione = $("#anni_situazione").text();
  anniVersamenti = $("#anni_versamenti").text();
  anniPagamenti = $("#anni_pagamenti").text();
  mostraViolazioni = $("#mostra_violazioni").text()=="true";
  test = $("#test").text()=="true";
  columns = {
    tari: {
      immobili: [
        { dataField: "indirizzo", text: "Indirizzo" },
        { dataField: "catasto", text: "Catasto", formatter: htmlFormatter },
        { dataField: "categoria", text: "Categoria", formatter: htmlFormatter },
        { dataField: "tipoTariffa", text: "Tipo tariffa" },
        { dataField: "mq", text: "Mq" },
        { dataField: "riduzioniApplicate", text: "Riduzioni applicate" },
        { dataField: "validita", text: "Validità" },
      ],
      pagamenti: [
        { dataField: "descrizioneAvviso", text: "Descrizione avviso", formatter: htmlFormatter },
        { dataField: "importoEmesso", text: "Importo emesso", formatter: numberFormatter },
        { dataField: "importoPagato", text: "Importo pagato", formatter: numberFormatter },
        { dataField: "importoResiduo", text: "Importo da pagare", formatter: numberFormatter },
        /*{ dataField: "azioni", text: "Azioni", formatter: buttonFormatter },*/ // commentato fino al 2020
      ],      
    },
    imutasi: {
      immobili: [
        { dataField: "indirizzo", text: "Indirizzo" },
        { dataField: "catasto", text: "Catasto", formatter: htmlFormatter },
        { dataField: "categoria", text: "Categoria", formatter: htmlFormatter },
        { dataField: "rendita", text: "Rendita", formatter: numberFormatter },
        { dataField: "possesso", text: "Titolo di possesso" },
        { dataField: "riduzioni", text: "Riduzioni applicate" },
        { dataField: "aliquota", text: "Aliquota" },
        { dataField: "validita", text: "Validità" },
      ], 
      pagamenti: [
        { dataField: "anno", text: "Anno" },
        { dataField: "rata", text: "Rata" },
        { dataField: "importoDovuto", text: "Importo dovuto", formatter: numberFormatter },
        { dataField: "importoVersato", text: "Importo versato", formatter: numberFormatter },
        { dataField: "totaleImportoDovuto", text: "Totale dovuto", formatter: numberFormatter },
        { dataField: "numeroImmobili", text: "N. immobili" },
        { dataField: "azioni", text: "Azioni", formatter: buttonFormatter },
      ],    
    },    
    versamenti: [
      { dataField: "imposta", text: "Imposta" },
      { dataField: "dataVersamento", text: "Data versamento", formatter: dateFormatter },
      // { dataField: "tipo", text: "Provenienza" },
      { dataField: "annoRiferimento", text: "Anno riferimento" },
      { dataField: "codiceTributo", text: "Codice tributo" },
      { dataField: "rata", text: "Rata" },
      { dataField: "detrazione", text: "Detrazione", formatter: numberFormatter  },
      { dataField: "totale", text: "Totale", formatter: numberFormatter },
      { dataField: "ravvedimento", text: "Ravvedimento", formatter: booleanFormatter },
    ]
  };
  // false -> discendente
  // true -> ascendente
  // si parte al contrario per permettere l'ordinamento iniziale (???)
  sortings = [
    {column:"annoRiferimento",order: true},
    {column:"imposta",order: false},
    {column:"codiceTributo",order: false},
    {column:"rata",order: false},
  ];
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
    this.state.selectedYear = { value: this.annoCorrente, label: this.annoCorrente };

    if(this.mostraViolazioni) {
      this.columns.versamenti.push({ dataField: "violazione", text: "Violazione", formatter: booleanFormatter })
    }
    
    this.authenticate();
  }
  
  componentDidUpdate(prevProps, prevState, snapshot) {
    
    console.log("AppTributi did update");
    var canBeResponsive = true;
    var self = this;
    if($('li.table-header').length==0) {
      $('<li class="table-header">').appendTo("body");
      canBeResponsive = typeof(tableToUl) === "function" && typeof($('li.table-header').css("font-weight"))!="undefined";
      $('li.table-header').remove();
    } 
    $("table.table-responsive").each(function(){
      var id = $(this).attr("id");
      if(canBeResponsive) {
        // var $backupHeader = $(this).find("tr").first().clone(true);
        console.log("Calling tableToUl on "+id);
        tableToUl($("#"+id));
        if($(this).attr("id")=="immobiliImu" || $(this).attr("id")=="immobiliTasi" || $(this).attr("id")=="immobiliTari") {
          $("#"+$(this).attr("id")+" li div:nth-of-type(1)").attr("class","cell-wide-4");
        }
        if(id=="versamenti" && self.test) {
          // aggiungo ordinamento
          $("#"+id).find(".table-header div").each(function(columnIndex){
            var column = $(this).text().toLowerCase().split(" ");
            if(typeof(column[1])!="undefined") {
              column = column[0]+ucfirst(column[1]);
            } else {
              column = column[0];
            }
            var sortable = self.sortings.some(sorting => sorting.column === column);
            if(sortable) {
              var thisSorting = self.sortings.filter(sorting => { return sorting.column === column })[0];
              var $sortButton = $("<button class='btn' id='sort_"+column+"'>"+$(this).text()+"<span>&#96"+(thisSorting.order===true?"5":"6")+"0;</span></button>");
              $sortButton.data("column", column);
              $sortButton.click(function(){
                var thisSorting = self.sortings.filter(sorting => { return sorting.column === column })[0];
                self.sortings[self.sortings.indexOf(thisSorting)].order = !self.sortings[self.sortings.indexOf(thisSorting)].order;
                self.sortings.sort(function(x,y){ return x.column == column ? -1 : y.column == column ? 1 : 0; });
                // console.log("Sorting versamenti by", self.sortings[0].column, self.sortings[0].order, "and then by", self.sortings[1].column, self.sortings[1].order);
                $(this).find("span").remove();
                $(this).append("<span>&#96"+(thisSorting.order===true?"5":"6")+"0;</span>");
                sortResponsiveTable($("#"+id),columnIndex,self.sortings);
                // self.sortVersamenti($(this).data("column"),self);
              });
              $(this).empty().append($sortButton);
            }
          });
          // ordino tabella
          $('#sort_rata').click();
          $('#sort_codiceTributo').click();
          $('#sort_imposta').click();
          $('#sort_annoRiferimento').click();
        }
        // $backupHeader.appendTo("<table>").insertBefore($("#"+id));
      } else  { console.log("tableToUl is not a function ("+typeof(tableToUl)+") or no css available for responsive tables"); } 
    });
  }

  sortVersamenti(column, self) {
    var state = self.state;
    var thisSorting = self.sortings.filter(sorting => { return sorting.column === column })[0];
    self.sortings[self.sortings.indexOf(thisSorting)].order = !self.sortings[self.sortings.indexOf(thisSorting)].order;
    self.sortings.sort(function(x,y){ return x.column == column ? -1 : y.column == column ? 1 : 0; });
    console.log("Sorting versamenti by", self.sortings[0].column, self.sortings[0].order, "and then by", self.sortings[1].column, self.sortings[1].order);
    state.versamenti.sort((a, b) => {
      var returnValue = 0;
      for(var sorting of self.sortings) {
        if (a[sorting.column] === b[sorting.column]) {
          // skip to next sorting
        } else {
          if(sorting.order===true) {
            returnValue = a[sorting.column] < b[sorting.column]?-1:1;
          } else {
            returnValue = b[sorting.column] < a[sorting.column]?-1:1;
          }
          break;
        }
      }   
      return returnValue;                 
    });
    self.setState(state);
    console.log(self.state.versamenti);
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
    $.get(this.dominio+"/soggetto", {data:{anno:this.state.selectedYear.value}}).done(function( response ) {
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
    $.get(this.dominio+"/tari_immobili", {data:{anno:this.state.selectedYear.value}}).done(function( response ) {
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
    $.get(this.dominio+"/tari_pagamenti", {data:{anno:this.state.selectedYear.value}}).done(function( response ) {
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
    $.get(this.dominio+"/imutasi_immobili", {data:{anno:this.state.selectedYear.value}}).done(function( response ) {
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
        // self.sortVersamenti("annoRiferimento", self);
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
    console.log("year changed to");
    console.log(selectedYear);
    delete state.tari.immobili;
    delete state.imu.immobili;
    delete state.tasi.immobili;
    //delete state.identificativoSoggetto;
    this.setState(state);
    console.log("state now is");
    console.log(this.state);
    this.getIdentificativo();
    this.getImmobiliTARI();
    this.getImmobiliIMUTASI();
  };
  
  render(){
    var options = [];
    
    console.log("rendering...");

    for(var i = this.annoCorrente; i>=this.annoCorrente-this.anniSituazione; i--){
      options.push({ value: i, label: i });
//       options.push(<option key={i} value={i} >{i}</option>);
//       options.push(i);
    }

    var returnVal = <div className="alert alert-warning">Dati contribuente non presenti nel sistema</div>
    if(this.state.identificativoSoggetto!=null) {
      console.log("drawing tables...");
      console.log("versamenti:", this.state.versamenti);
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
            <h3>Situazione immobili per l'anno <div style={{width: '128px', display: 'inline-block'}}><Select options={options} onChange={this.changeYear} defaultValue={this.state.selectedYear} /></div></h3>
            <h4>TARI - Tassa Rifiuti</h4>
            {typeof(this.state.tari.immobili) == "undefined" ? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> : this.state.tari.immobili.length>0 ? <BootstrapTable
                id="immobiliTari"
                keyField={"id"}
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
            <div className={ typeof(this.state.selectedYear)!="undefined"&&this.state.selectedYear.value<2020?"show":"hidden" }>
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
          </div>
          
          <div role="tabpanel" className="tab-pane" id="pagamenti">
            <h3>Elenco versamenti per gli anni {this.annoCorrente-this.anniVersamenti} - {this.annoCorrente}</h3>
            {typeof(this.state.versamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.versamenti.length>0 ? <BootstrapTable
                id="versamenti"
                keyField={"id"}
                data={this.state.versamenti}
                columns={this.columns.versamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Nessun risultato per gli anni {this.annoCorrente-this.anniVersamenti} - {this.annoCorrente}</p> }
          </div>
          
          <div role="tabpanel" className="tab-pane" id="ravvedimenti">
            <h3>Elenco pagamenti in sospeso per gli anni {this.annoCorrente-this.anniPagamenti} - {this.annoCorrente}</h3>
            <h4>TARI - Tassa Rifiuti</h4>
            {typeof(this.state.tari.pagamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> : this.state.tari.pagamenti.length>0 ? <BootstrapTable
                id="pagamentiTari"
                keyField={"descrizioneAvviso"}
                data={this.state.tari.pagamenti}
                columns={this.columns.tari.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-this.anniPagamenti} - {this.annoCorrente}</p> }
            <h4>IMU - Imposta sugli Immobili</h4>
            {typeof(this.state.imu.pagamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.imu.pagamenti.tabella.length>0 ? <BootstrapTable
                id="pagamentiImu"
                keyField={"azioni"}
                data={this.state.imu.pagamenti.tabella}
                columns={this.columns.imutasi.pagamenti}
                classes="table-responsive"
                striped
                hover
              /> : <p className="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-this.anniPagamenti} - {this.annoCorrente}</p> }
            <div className={ typeof(this.state.selectedYear)!="undefined"&&this.state.selectedYear.value<2020?"show":"hidden" }>       
              <h4>TASI - Tributo Servizi Indivisibili</h4>
              {typeof(this.state.tasi.pagamenti) == "undefined"? <p className="text-center"><FontAwesomeIcon icon={faCircleNotch}  size="2x" spin /><span className="sr-only">caricamento...</span></p> :this.state.tasi.pagamenti.tabella.length>0 ? <BootstrapTable
                  id="pagamentiTasi"
                  keyField={"azioni"}
                  data={this.state.tasi.pagamenti.tabella}
                  columns={this.columns.imutasi.pagamenti}
                  classes="table-responsive"
                  striped
                  hover
                /> : <p className="text-center">Tutti i pagamenti risultano in regola per per gli anni {this.annoCorrente-this.anniPagamenti} - 2020</p> }      
              </div>
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

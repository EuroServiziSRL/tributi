require 'httparty'
require 'uri'
require "base64"
require 'openssl'

class ApplicationController < ActionController::Base
  include ApplicationHelper
  @@api_resource = "https://api.civilianext.it"
  @@api_url = "#{@@api_resource}/Tributi/api/"
  
  #ROOT della main_app
  def index
    #permetto di usare tutti i parametri e li converto in hash
    hash_params = params.permit!.to_hash
    # TEST
#     session[:cf] = "BTTGNN15A30G694R"
    @numero_anni_default = 2

    if !hash_params['c_id'].blank? && session[:client_id] != hash_params['c_id']
      reset_session
    end
  
    if true || session.blank? || session[:user].blank? #controllo se ho fatto login
      #se ho la sessione vuota devo ottenere una sessione dal portale
      #se arriva un client_id (parametro c_id) e id_utente lo uso per richiedere sessione
      if !hash_params['c_id'].blank? && !hash_params['u_id'].blank?

        #ricavo dominio da oauth2
        url_oauth2_get_info = "https://login.soluzionipa.it/oauth/application/get_info_cid/"+hash_params['c_id']
        #url_oauth2_get_info = "http://localhost:3001/oauth/application/get_info_cid/"+hash_params['c_id'] #PER TEST
        result_info_ente = HTTParty.get(url_oauth2_get_info,
          :headers => { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } )
        hash_result_info_ente = result_info_ente.parsed_response
        @dominio = hash_result_info_ente['url_ente']
        #@dominio = "https://civilianext.soluzionipa.it/portal" #per test
        session[:dominio] = @dominio
        #creo jwt per avere sessione
        hash_jwt_app = {
          iss: 'tributi.soluzionipa.it', #dominio finale dell'app tributi
          id_app: 'tributi',
          id_utente: hash_params['u_id'],
          sid: hash_params['sid'],
          api_next: true
        }
        jwt = JsonWebToken.encode(hash_jwt_app)
        #richiesta in post a get_login_session con authorization bearer
        result = HTTParty.post(@dominio+"/autenticazione/get_login_session", 
          :body => hash_params,
          :headers => { 'Authorization' => 'Bearer '+jwt } )
        hash_result = result.parsed_response
        #se ho risultato con stato ok ricavo dati dal portale e salvo in sessione 
        #impostare durata sessione in application.rb: ora dura 30 minuti
        if !hash_result.blank? && !hash_result["stato"].nil? && hash_result["stato"] == 'ok'
          jwt_data = JsonWebToken.decode(hash_result['token'])
          session[:user] = jwt_data #uso questo oggetto per capire se utente connesso!
          session[:cf] = jwt_data[:cf]
          @nome = jwt_data[:nome]
          @cognome = jwt_data[:cognome]
          session[:client_id] = hash_params['c_id']
          # TODO gestire meglio il dominio
          solo_dom = @dominio.gsub("/portal","")
          session[:url_stampa] = "#{solo_dom}/openweb/_ici/imutasi_stampa.php"
          if !jwt_data[:numero_anni].nil? && jwt_data[:numero_anni] != "" && jwt_data[:numero_anni] > 0 
            session[:numero_anni] = jwt_data[:numero_anni]
          else
            session[:numero_anni] = @numero_anni_default
          end
          @numero_anni = session[:numero_anni]
        else
          #se ho problemi ritorno su portale con parametro di errore
          unless @dominio.blank?
            redirect_to @dominio+"/?err"
            return
          else
            redirect_to sconosciuto_url
            return   
          end
          
        end
      else

        unless @dominio.blank?
          #mando a fare autenticazione sul portal
          redirect_to @dominio+"/autenticazione"
          return
        else
          redirect_to sconosciuto_url
          return    
        end
        
      end
    else
      @dominio = session[:dominio] || "dominio non presente"
    end
    #carico cf in variabile per usarla sulla view
    @cf_utente_loggato = session[:cf]
    #ricavo l'hash del layout
    result = HTTParty.get(@dominio+"/get_hash_layout", 
      :body => {})
    hash_result = JSON.parse(result.parsed_response)
    if hash_result['esito'] == 'ok'
      hash_layout = hash_result['hash']
      nome_file = "#{session[:client_id]}_#{hash_layout}.html.erb"
      #cerco if file di layout se presente uso quello
      if Dir["#{Rails.root}/app/views/layouts/layout_portali/#{session[:client_id]}_#{hash_layout}.*"].length == 0
        #scrivo il file
        #cancello i vecchi file con stesso client_id (della stesa installazione)
        Dir["#{Rails.root}/app/views/layouts/layout_portali/#{session[:client_id]}_*"].each{ |vecchio_layout|
          File.delete(vecchio_layout) 
        }
        #richiedo il layout dal portale
        result = HTTParty.get(@dominio+"/get_html_layout", :body => {})
        hash_result = JSON.parse(result.parsed_response)
        html_layout = Base64.decode64(hash_result['html'])
        #Aggiungo variabile per disabilitare Function.prototype.bind in portal.x.js
        js_da_iniettare = '<script type="text/javascript">window.appType = "external";</script>'
        #Devo iniettare nel layout gli assets e lo yield
        head_da_iniettare = "<%= csrf_meta_tags %>
        <%= csp_meta_tag %>
        <%= stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track': 'reload' %>"
        html_layout = html_layout.gsub("</head>", head_da_iniettare+"</head>").gsub("id=\"portal_container\">", "id=\"portal_container\"><h2>Consultazione posizione IUC</h2><%=yield%><div class=\"bottoni_pagina\"><div class=\"row\"><div class=\"col-lg-6 col-md-6 col-sm-12 col-xs-12\"><div class=\"back\"><a class=\"btn\" href=\"#{@dominio}\">Torna al portale</a></div></div></div></div>")
        html_layout = html_layout.gsub("<head>","<head> "+js_da_iniettare)
        #parte che include il js della parte react sul layout CHE VA ALLA FINE, ALTRIMENTI REACT NON VA
        html_layout = html_layout.gsub("</body>","<%= javascript_pack_tag 'app_tributi' %> </body>")
        # doc_html = Nokogiri::HTML.parse(html_layout)
        # doc_html.at_css("head").add_next_sibling(head_da_iniettare)
        # doc_html.at_css("#portal_container").add_child("<div id=\"tributi_main\"><%=yield%></div>")


        path_dir_layout = "#{Rails.root}/app/views/layouts/layout_portali/"
        File.open(path_dir_layout+nome_file, "w") { |file| file.puts html_layout.force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8) }
      end
    else
      logger.error "Portale cittadino #{@dominio} non raggiungibile per ottenere hash di layout!"
    end  

#     render :json => session
    render :template => "application/index" , :layout => "layout_portali/#{nome_file}"
    
#     result = stato_pagamento("#{@dominio.gsub("https","http")}/servizi/pagamenti/ws/stato_pagamenti",3733696)
#     render :json => result
  end

  
  def sconosciuto
  end

  def authenticate  
    params = {
       "targetResource": "#{@@api_resource.sub("https","http")}", 
       "tenantId": "#{session[:user]["api_next"]["tenant"]}",
       "clientId": "#{session[:user]["api_next"]["client_id"]}",
       "secret": "#{session[:user]["api_next"]["secret"]}"
    }
    #logger.debug params
    result = HTTParty.post("#{@@api_url}utilities/AuthenticationToken?v=1.0", 
    :body => params.to_json,
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json'  } )

    if !result["result"].nil? && result["result"].length>0
      session[:token] = result["result"]["token"]
    end
    
    render :json => result
  end  
  
  def soggetto
    params[:data][:tipoRicerca] = "RicercaPerCodiceFiscale"
    params[:data][:codiceFiscale] = session[:cf]
    result = HTTParty.get("#{@@api_url}soggetti/GetSoggettiTributi?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } )    
    
    if !result["result"].nil? && result["result"].length>0
      session[:identificativoSoggetto] = result["result"]["identificativoSoggetto"]
      session[:cognome] = result["result"]["cognome"].strip
      session[:nome] = result["result"]["nome"].strip
    end
    
    render :json => result    
  end
  
  def tari_immobili
    params[:data][:tipoRicerca] = "RicercaPerSoggetto"
    params[:data][:identificativoSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}occupazioni/GetOccupazioni?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    tabellaTasi = []
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
        resultIndirizzo = HTTParty.get("#{@@api_url}immobiliTributi/GetIndirizziImmobiliTributi?v=1.0&request[tipoRicerca]=RicercaPerNumeroUtenza&request[numeroUtenza]=#{value['numeroUtenza']}", 
        :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
        
        
        isDomestica = !value['domestica'].nil? && value['domestica']=="Si"
        domestica = isDomestica ? "Domestica":"Non domestica"
        componenti = isDomestica ? " - #{value["listaNucleoFam"][0]["numeroComponenti"]} componenti dal #{value["listaNucleoFam"][0]["datainizio"]}":""
        date_start = DateTime.parse(value["dataInizio"])
        formatted_date_start = date_start.strftime('%d/%m/%Y')
        formatted_date_end = ""
        if value["dataFine"]!=""
          date_end = DateTime.parse(value["dataFine"])
          formatted_date_end = date_end.strftime('%d/%m/%Y')
        end
        
        stringavalidita = "dal #{formatted_date_start}"
        if !date_end.nil? && date_end.strftime('%Y') != "9999"
          stringavalidita = "dal #{formatted_date_start} al #{formatted_date_end}"
        end
        datiImmobile = {'tipoTariffa': "#{domestica} - #{value['codiceCategoria']}#{componenti}", "mq": value['totaleSuperficie'], "validita": stringavalidita}
        if !value['listaImmobile'].nil? && value['listaImmobile'].length>0
          datiImmobile['indirizzo'] = resultIndirizzo["result"][0]['indirizzoCompleto']
#           datiImmobile['indirizzo'] = "#{resultIndirizzo.to_json}"
          datiImmobile['catasto'] = "#{value['listaImmobile'][0]['foglio']}/#{value['listaImmobile'][0]['numero']}/#{value['listaImmobile'][0]['subalterno']}"
        else
          datiImmobile['indirizzo'] = ""
          datiImmobile['catasto'] = ""
        end
        if !value['listaRiduzioneOccupazione'].nil? && value['listaRiduzioneOccupazione'].length>0
          datiImmobile['riduzioniApplicate'] = value['listaRiduzioneOccupazione'][0]['riduzione']['descrizione']
        else 
          datiImmobile['riduzioniApplicate'] = ""
        end
        tabellaTasi << datiImmobile
      end
    end
    tabellaTasi = tabellaTasi.sort_by { |hsh| hsh[:catasto] }
    
    render :json => tabellaTasi    
  end
  
  def tari_pagamenti
#     params[:data][:idSoggetto] = session[:identificativoSoggetto]
      
    tabellaTasi = []
    
    for anno in (Date.current.year-3)..Date.current.year do
      result = HTTParty.get("#{@@api_url}avvisiPagamento/GetAvvisiPagamento?v=1.0&request[idSoggetto]=#{session[:identificativoSoggetto]}&request[anno]=#{anno}", 
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
      
      if !result["result"].nil? && result["result"].length>0
        result["result"].each do |value|
          if (value['dataAnnullamento'].blank?) && value["importoResiduo"].gsub(',', '.').to_f>0           
            statoPagamenti = stato_pagamento("#{session[:dominio].gsub("https","http")}/servizi/pagamenti/ws/stato_pagamenti",value["idAvviso"])
#             statoPagamento = stato_pagamento(value["idAvviso"])
            # Pagato - Pendente - Da Ricaricare - In Attesa RT - Annullato - Non Eseguito - Decorrenza termini - Eliminato d'Ufficio, Avviato
            if(!statoPagamenti.nil? && statoPagamenti["esito"]=="ok" && (statoPagamenti["esito"][0]["stato"]=="Pagato"))
              # pagamento ok, non lo mettiamo in lista
            else
              date = DateTime.parse(value["dataAvviso"])
              formatted_date = date.strftime('%d/%m/%Y')
              
              parametri = {
                importo: "#{value["importoResiduo"].gsub(',', '.')}",
                descrizione: "#{value["codiceAvvisoDescrizione"]} - n.#{value["numeroAvviso"]}",
                codice_applicazione: "istanze", # TODO da cambiare con qualcosa di più appropriato
                url_back: request.protocol + request.host_with_port,
                idext: value["idAvviso"],
                tipo_elemento: "tari",
                nome_versante: session[:nome],
                cognome_versante: session[:cognome],
                codice_fiscale_versante: session[:cf],
                nome_pagatore: session[:nome],
                cognome_pagatore: session[:cognome],
                codice_fiscale_pagatore: session[:cf]
              }
              
              queryString = [:importo, :descrizione, :codice_applicazione, :url_back, :idext, :tipo_elemento, :nome_versante, :cognome_versante, :codice_fiscale_versante, :nome_pagatore, :cognome_pagatore, :codice_fiscale_pagatore].map{ |chiave|
                  val = parametri[chiave] 
                  "#{chiave}=#{val}"
              }.join('&')
              
#               puts "query string for sha1 is [#{queryString.strip}]"
#               queryString = "importo=#{value["importoResiduo"].gsub(',', '.')}&descrizione=#{value["codiceAvvisoDescrizione"]} - n.#{value["numeroAvviso"]}&codice_applicazione=tributi&url_back=#{request.original_url}&idext=#{value["idAvviso"]}&tipo_elemento=pagamento_tari&nome_versante=#{session[:nome]}&cognome_versante=#{session[:cognome]}&codice_fiscale_versante=#{session[:cf]}&nome_pagatore=#{session[:nome]}&cognome_pagatore=#{session[:cognome]}&codice_fiscale_pagatore=#{session[:cf]}"
              fullquerystring = URI.unescape(queryString)
              qs = fullquerystring.sub(/&hqs=\w*/,"").strip+"3ur0s3rv1z1"
              hqs = OpenSSL::Digest::SHA1.new(qs)
#               puts "hqs is [#{hqs}]"
              azioni = "#{session[:dominio]}/servizi/pagamenti/"
              if(statoPagamenti.nil? || !statoPagamenti["esito"]=="ok")
                azioni = "#{session[:dominio]}/servizi/pagamenti/aggiungi_pagamento_pagopa?#{queryString}"
              end
              queryString = "#{queryString}&hqs=#{hqs}"
              tabellaTasi << {"descrizioneAvviso": "#{value["codiceAvvisoDescrizione"]} - n.#{value["numeroAvviso"]} del #{formatted_date}", "importoEmesso": value["importoTotale"], "importoPagato": value["importoVersato"], "importoResiduo": value["importoResiduo"], "azioni": azioni}
            end
          end
        end
      end
    end
    
    render :json => tabellaTasi    
  end
  
  def imutasi_immobili
    params[:data][:tipoRicerca] = "RicercaPerSoggetto"
    params[:data][:identificativoSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}titolarita/GetTitolarita?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    subCaratteristiche = ['','abitazione principale', 'pertinenza', 'rurale', 'bene merce']
    
    tabellaImu = []
    tabellaTasi = []
    counterImu = 1
    counterTasi = 1
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
        
        date_start = DateTime.parse(value["dataInizio"])
        formatted_date_start = date_start.strftime('%d/%m/%Y')
        date_end = DateTime.parse(value["dataFine"])
        formatted_date_end = date_end.strftime('%d/%m/%Y')
        
        stringavalidita = "dal #{formatted_date_start}"
        if date_end.strftime('%Y') != "9999"
          stringavalidita = "dal #{formatted_date_start} al #{formatted_date_end}"
        end
        
        subCaratteristica = ""
        if !value["subCaratteristica"].nil?
          subCaratteristica = subCaratteristiche[value["subCaratteristica"]]
        end
        
        indirizzo = "";
        if !value["listaImmobileTributi"][0]["indirizzo"].nil? && value["listaImmobileTributi"][0]["indirizzo"]!=""
          indirizzo = value["listaImmobileTributi"][0]["indirizzo"]
        elsif !value["listaImmobileTributi"][0]["unitaAbitativa"].nil? && !value["listaImmobileTributi"][0]["unitaAbitativa"].blank?
          indirizzo = "#{value["listaImmobileTributi"][0]["unitaAbitativa"]["numeroCivicoEsterno"]["strada"]["toponimo"]["descrizione"]} #{value["listaImmobileTributi"][0]["unitaAbitativa"]["numeroCivicoEsterno"]["strada"]["denominazione"]} #{value["listaImmobileTributi"][0]["unitaAbitativa"]["numeroCivicoEsterno"]["numero"]}"
        end
          
        datiImmobile = { 
          "rendita": value["rendita"], 
          "validita": stringavalidita,
          "categoria": !value["categoriaCatastale"].nil? ? value["categoriaCatastale"]["codice"] : '',
          "aliquota": !value["aliquota"].nil? ? value["aliquota"]["descrizione"] : "#{subCaratteristica}",
          "catasto": "#{value["listaImmobileTributi"][0]["foglio"]}/#{value["listaImmobileTributi"][0]["numero"]}/#{value["listaImmobileTributi"][0]["subalterno"]}",
          "indirizzo": indirizzo
        }
        if !value["tipoTitolarita"].nil? && value["tipoTitolarita"].length > 0     
          datiImmobile['possesso'] = "#{value["percentualePossesso"]}% #{value["tipoTitolarita"]["descrizione"]}"
        end
        riduzioni = []
        if value['storico']
          riduzioni << "storico"
        end
        if value['inagibile']
          riduzioni << "inagibile"
        end
        if value['esenteEscluso']==2
          riduzioni << "esente"
        end
        datiImmobile['riduzioni'] = riduzioni.join(" - ")
        if value["quotaServiziIndivisibili"]==100
          datiImmobileTasi = datiImmobile.clone();
          datiImmobileTasi['id'] = "Tasi-#{counterTasi}"
          tabellaTasi << datiImmobileTasi
          counterTasi = counterTasi+1
        end 
        datiImmobile['id'] = "Imu-#{counterImu}"
        tabellaImu << datiImmobile
        counterImu = counterImu+1
      end
    end
    tabellaImu = tabellaImu.sort_by { |hsh| hsh[:catasto] }
    tabellaTasi = tabellaTasi.sort_by { |hsh| hsh[:catasto] }
    
    render :json => {"imu": tabellaImu, "tasi": tabellaTasi}
  end
  
  def versamenti
    tabellaImu = [] 
      
    result = HTTParty.get("#{@@api_url}versamentiF24/GetVersamentiF24?v=1.0&codiceFiscale=#{session[:cf]}",
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } )  
  
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
        tabellaImu << {
          "imposta": value["desImposta"],
          "dataVersamento": value["dataRiscossione"],
          "annoRiferimento": value["annoRiferimento"],
          "tipo": "F24",
          "codiceTributo": value["codiceTributo"],
          "acconto": value["acconto"],
          "saldo": value["saldo"],
          "detrazione": value["detrazione"],
          "totale": value["importoDebito"],
          "ravvedimento": value["ravvedimento"],
          "violazione": value["violazione"]
        }
      end
    end
    
    for anno in 2012..Date.current.year do
      # serve davvero farlo una volta per imposta? verificare con dati reali
#       result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}&imposta=IciImu", 
#       result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}",
      result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}",
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } )  
    
      #if result.is_a?(Array) && !result["result"].nil? && result["result"].length>0
      if !result["result"].nil? && result["result"].length>0
        result["result"].each do |value|
          tabellaImu << {
            "imposta": value["modulo"],
            "dataVersamento": value["dataPagamento"],
            "annoRiferimento": value["anno"],
            "tipo": value["tipoVersamento"],
            "codiceTributo": value["codiceTributoF24"],
            "acconto": value["dettaglioRata"]=="1"?"Si":"",
            "saldo": value["dettaglioRata"]=="2"?"Si":"",
            "detrazione": value["importoDetrazione"],
            "totale": value["importo"],
            "ravvedimento": value["ravvedimento"],
	    "violazione": value["violazione"]=="false"?"Si":""
          }
        end
      end
      
      result2 = HTTParty.get("#{@@api_url}versamentiMultiCanale/GetVersamentiMultiCanale?v=1.0&codiceFiscale=#{session[:cf]}&annoRiferimento=#{anno}&imposta=Tasi", 
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } )  
    
      if !result2["result"].nil? && result2["result"].length>0
        result2["result"].each do |value|
          tabellaImu << {
            "imposta": value["desImposta"],
            "dataVersamento": value["dataPagamento"],
            "annoRiferimento": value["anno"].strip.to_i,
            "tipo": value["canale"],
            "codiceTributo": value["codiceTributo"],
            "acconto": value["codiceRata"],
            "saldo": value["codiceRata"],
            "detrazione": 0,
            "totale": value["importo"],
            "ravvedimento": value["ravvedimento"],
            "violazione": false
          }
        end
      end            
      
    end

    tabellaImu = tabellaImu.sort_by { |hsh| hsh[:annoRiferimento] }.reverse
    
    render :json => tabellaImu    
  end
   
  def imutasi_pagamenti
    params[:data][:idSoggetto] = session[:identificativoSoggetto]
    
    tabellaImu = []
    listaF24 = {}
      
    codiciTributo = {
      "3912"=> "abitazione",
      "3913"=> "rurali",
      "3915"=> "terreni",
      "3914"=> "terreniC",
      "3916"=> "areeC",
      "3917"=> "aree",
      "3918"=> "altriC",
      "3919"=> "altri",
      "3930"=> "prodC",
      "3925"=> "prod",
      "3958"=> "abitazioneT",
      "3959"=> "ruraliT",
      "3960"=> "areeT",
      "3961"=> "altriT"
    }
    
    results = []
    
    log = ""
    
    for anno in (Date.current.year-session[:numero_anni])..Date.current.year do
      #serve una per anno, perchè senò si sovrascrivono i valori      
      strutturaF24 = {"Acconto"=>{"totale"=>0,"totaleRavv"=>0,"det"=>0,"num"=>0},"Saldo"=>{"totale"=>0,"totaleRavv"=>0,"det"=>0,"num"=>0},"Unica"=>{"totale"=>0,"totaleRavv"=>0,"det"=>0,"num"=>0}}
      codiciTributo.each do |codice, stringaTributo| 
        stringaNum = "#{stringaTributo}"
        stringaNum = stringaNum.chomp("1").chomp("2").chomp("C")
        stringaNum[0] = stringaNum[0,1].upcase
        stringaNum = "num#{stringaNum}"

        strutturaF24["Unica"][stringaTributo] = 0
        strutturaF24["Unica"][stringaNum] = 0
        strutturaF24["Acconto"][stringaTributo] = 0
        strutturaF24["Acconto"][stringaNum] = 0
        strutturaF24["Acconto"]["num"] = 0
        strutturaF24["Acconto"]["dovuto"] = 0
        strutturaF24["Acconto"]["dovutoPre"] = 0
        strutturaF24["Acconto"]["versato"] = 0
        strutturaF24["Saldo"][stringaTributo] = 0
        strutturaF24["Saldo"][stringaNum] = 0
        strutturaF24["Saldo"]["num"] = 0
        strutturaF24["Saldo"]["dovuto"] = 0
        strutturaF24["Saldo"]["dovutoPre"] = 0
        strutturaF24["Saldo"]["versato"] = 0
      end
    
      params[:data][:anno] = anno
      result = HTTParty.get("#{@@api_url}importiPreliquidati/GetDettaglioPreliquidato?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
      results << result
      
      if !result["result"].nil? && result["result"].length>0        
        
        result["result"].each_with_index do |value, i|
          totale = value["totaleImportoDovuto"].gsub(',', '.').to_f
          importoNonZero = value["totaleImportoDovuto"].gsub(',', '.').to_f > 0
          compensaSaldo = value["rata"]=="Acconto" && !result["result"][i+1].nil? && result["result"][i+1]["rata"]=="Saldo" && result["result"][i+1]["importoVersato"].gsub(',', '.').to_f > result["result"][i+1]["importoVersatoConsiderato"].gsub(',', '.').to_f
          log = log+"[importoNonZero:#{importoNonZero},value-rata:#{value["rata"]},result+1:#{!result["result"][i+1].nil?}]"

#           datiF24 = { 
#             "anno": anno, 
#             "rata": value["rata"], 
#             "importoVersato": value["importoVersato"], 
#             "totaleImportoDovuto": value["totaleImportoDovuto"], 
#             "numeroImmobili": value["numeroImmobili"], 
#           }
#           tabellaImu << datiF24
          if importoNonZero || compensaSaldo
    
            listaF24[anno] = strutturaF24
            stringaTributo = codiciTributo[value["codiceTributo"]]
            stringaNum = "#{stringaTributo.chomp("1")}"
            stringaNum = "#{stringaNum.chomp("2")}"
            stringaNum = "#{stringaNum.chomp("C")}"
            stringaNum = stringaTributo
            stringaNum[0] = stringaNum[0,1].upcase
            stringaNum = "num#{stringaNum}"
            if listaF24[anno][value["rata"]][stringaNum].nil?
              listaF24[anno][value["rata"]][stringaNum] = 0
            end
            if listaF24[anno][value["rata"]][stringaTributo].nil?
              listaF24[anno][value["rata"]][stringaTributo] = 0
            end
            if listaF24[anno]["Unica"][stringaTributo].nil?
              listaF24[anno]["Unica"][stringaTributo] = 0
            end
            if !value["rata"].nil? && !listaF24.nil? && !listaF24[anno][value["rata"]].nil?
              if importoNonZero || compensaSaldo
                listaF24[anno][value["rata"]]["totale"] += totale
                listaF24[anno][value["rata"]]["totaleRavv"] += totale
                listaF24[anno]["Unica"]["totaleRavv"] += totale
                listaF24[anno]["Unica"]["totale"] += totale
                
                log = log+"adding #{value["numeroImmobili"]} to #{stringaNum} for codice tributo #{value["codiceTributo"]} rata #{value["rata"]} anno #{anno} #{value}| "
                
                listaF24[anno][value["rata"]][stringaTributo] += totale
                listaF24[anno][value["rata"]][stringaNum] += value["numeroImmobili"]
                listaF24[anno][value["rata"]]["num"] += value["numeroImmobili"]
                listaF24[anno][value["rata"]]["det"] += value["detrazioneUtilizzata"].gsub(',', '.').to_f
                listaF24[anno][value["rata"]]["dovuto"] += value["totaleImportoDovuto"].gsub(',', '.').to_f
                listaF24[anno][value["rata"]]["versato"] += value["importoVersatoConsiderato"].gsub(',', '.').to_f
                listaF24[anno][value["rata"]]["dovutoPre"] += value["importoDovuto"].gsub(',', '.').to_f
                listaF24[anno]["Unica"]["totale"] += totale
                if value["rata"] == "Acconto" 
                  listaF24[anno]["Unica"]["num"] += value["numeroImmobili"]
                  listaF24[anno]["Unica"][stringaNum] = value["numeroImmobili"]
                end
              
                listaF24[anno]["Unica"][stringaTributo] += totale
              else 
                log = log + "Deleting #{value["rata"]} from #{anno} (564)|";
                listaF24[anno].tap { |hs| hs.delete(value["rata"]) }
              end
            end
          else
            log = log + "Deleting #{value["rata"]} from #{anno} (568)|";
            listaF24[anno].tap { |hs| (!hs.nil? && !hs[value["rata"]].nil?) ? hs.delete(value["rata"]) : next }
          end
        end      
      end
      
    end
        
    
    
    listaF24.each do |anno, f24|
      data_pagamento = DateTime.parse(params[:data][:dataPagamento])
      data_pagamento = data_pagamento.strftime('%d/%m/%Y')

      url_stampa = "ravv=1&dataRavv=#{data_pagamento}&cognome=#{session[:cognome]}&nome=#{session[:nome]}&appTributi=true&cf=#{session[:cf]}&anno=#{anno}&stampaImposta=#{(params[:data][:modulo]=="Imposta_Immobili"?"IMU":"TASI")}&sanzioni=1"
      
      f24.each do |nomeRata, datiRata|
        numRata = ""
#         if nomeRata == "Acconto" || nomeRata == "Saldo"
#           numRata = nomeRata=="Acconto"?"1":"2"
#           datiRata.each do |key, value|
#             if key.end_with? "C"
#               queryKey = "#{key.chomp("C")}#{numRata}C"
#             elsif key.end_with? "T"
#               queryKey = "#{key.chomp("T")}#{numRata}T"
#             else
#               queryKey = "#{key}#{numRata}"
#             end
#             
#             url_stampa += "&#{queryKey}=#{value}"
#           end
#         end
          numRata = nomeRata=="Unica"?"":(nomeRata=="Acconto"?"1":"2")
          datiRata.each do |key, value|
            if key.end_with? "C"
              queryKey = "#{key.chomp("C")}#{numRata}C"
            elsif key.end_with? "T"
              queryKey = "#{key.chomp("T")}#{numRata}T"
            else
              queryKey = "#{key}#{numRata}"
            end
            
            queryKey[0] = queryKey[0].downcase;
            
            url_stampa += "&#{queryKey}=#{value}"
          end
        
      end
      
      f24.each do |nomeRata, datiRata|       
        if nomeRata == "Acconto" || nomeRata == "Saldo"
          url_stampa_rata = url_stampa+"&totale=#{f24[nomeRata]['totale']}&det=#{f24[nomeRata]["det"]}&num=#{f24[nomeRata]["num"]}"
          
          datiF24 = { 
            "anno": anno, 
            "rata": nomeRata, 
            "importoDovuto": datiRata["dovutoPre"],
            "importoVersato": datiRata["versato"], 
            "totaleImportoDovuto": datiRata["totale"], 
            "numeroImmobili": datiRata["num"], 
#             "azioni": "<a href='#{session[:url_stampa]}?rata=#{nomeRata.downcase}&#{nomeRata.downcase}=true&#{url_stampa}'>Stampa</a>"
            "azioni": "#{session[:url_stampa]}?rata=#{nomeRata.downcase}&#{nomeRata.downcase}=true&#{url_stampa_rata}"
          }
          tabellaImu << datiF24
        
        end
        
      end
      
    end
    
#     urls = {"acconto":"#{session[:url_stampa]}?rata=acconto&acconto=true&#{url_stampa}", "saldo":"#{session[:url_stampa]}?rata=saldo&saldo=true&#{url_stampa}"}
    
#     render :json => {"tabella": tabellaImu, "urls": urls, "listaF24": listaF24}
    render :json => {"log": log, "tabella": tabellaImu, "listaF24": listaF24, "results": results}
#     render :json => {"tabella": tabellaImu, "listaF24": listaF24}
  end
  
  #da fare
  def error_dati
  end
    
end

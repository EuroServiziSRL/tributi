require 'httparty'
require 'uri'
require "base64"
require 'openssl'

class ApplicationController < ActionController::Base
  include ApplicationHelper
  @@api_resource = "https://api.civilianext.it"
  @@api_url = "#{@@api_resource}/Tributi/api/"
  @@log_level = 3
  @@log_to_output = true
  @@log_to_file = false

  def ignore
  end
  
  #ROOT della main_app
  def index
    #permetto di usare tutti i parametri e li converto in hash
    hash_params = params.permit!.to_hash
    # TEST
    #session[:cf] = "BTTGNN15A30G694R"
    @anni_situazione_default = 3
    @anni_versamenti_default = 5
    @anni_pagamenti_default = 3
    @tipologia_versamenti_default = "Non_Travasati"
    @mostra_violazioni_default = false
    @test = params["test"].nil? ? false : true
  
    if !hash_params['c_id'].blank? && session[:client_id] != hash_params['c_id']
      reset_session
    end

    if true || session.blank? || session[:user].blank? #controllo se ho fatto login
      #se ho la sessione vuota devo ottenere una sessione dal portale
      #se arriva un client_id (parametro c_id) e id_utente lo uso per richiedere sessione
      if !hash_params['c_id'].blank? && !hash_params['u_id'].blank?

        #ricavo dominio da oauth2
        url_oauth2_get_info = "https://login.soluzionipa.it/oauth/application/get_info_cid/"+hash_params['c_id']
        # puts url_oauth2_get_info
        # url_oauth2_get_info = "http://localhost:3001/oauth/application/get_info_cid/"+hash_params['c_id'] #PER TEST
        result_info_ente = HTTParty.get(
          url_oauth2_get_info,
          :headers => { 
            'Content-Type' => 'application/json', 
            'Accept' => 'application/json' ,
            # :debug_output => $stdout 
          } 
        )
        # puts result_info_ente.parsed_response
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
        result = HTTParty.post(@dominio+"/autenticazione/get_login_session.json", 
          :body => hash_params,
          :headers => { 'Authorization' => 'Bearer '+jwt } )
        hash_result = result.parsed_response
        #se ho risultato con stato ok ricavo dati dal portale e salvo in sessione 
        #impostare durata sessione in application.rb: ora dura 30 minuti
        if !hash_result.blank? && !hash_result["stato"].nil? && hash_result["stato"] == 'ok'
          jwt_data = JsonWebToken.decode(hash_result['token'])
          debug_message("jwt data received", 1)
          debug_message(jwt_data, 1)
          session[:user] = {} #uso questo oggetto per capire se utente connesso!
          session[:user][:api_next] = jwt_data[:api_next]
          session[:cf] = jwt_data[:cf]
          @nome = jwt_data[:nome] 
          @cognome = jwt_data[:cognome]
          session[:client_id] = hash_params['c_id']
          # TODO gestire meglio il dominio
          solo_dom = @dominio.gsub(/\/portal(\/?)\Z/,"")
          # session[:get_belfiore_url] = "#{solo_dom}/openweb/portal/api/getCodiceBelfiore.php"
          session[:belfiore] = jwt_data[:codice_belfiore]
          # debug_message("session[:belfiore]", 1)
          # debug_message(session[:belfiore], 1)

          session[:anni_situazione] = value_or_default(jwt_data[:api_next][:anni_situazione], @anni_situazione_default).to_i
          session[:anni_versamenti] = value_or_default(jwt_data[:api_next][:anni_versamenti], @anni_versamenti_default).to_i
          session[:anni_pagamenti] = value_or_default(jwt_data[:api_next][:anni_pagamenti], @anni_pagamenti_default).to_i
          session[:tipologia_versamenti] = value_or_default(jwt_data[:api_next][:tipologia_versamenti], @tipologia_versamenti_default)
          session[:mostra_violazioni] = value_or_default(jwt_data[:api_next][:mostra_violazioni], @mostra_violazioni_default)

          @anni_situazione = session[:anni_situazione]
          @anni_versamenti = session[:anni_versamenti]
          @anni_pagamenti = session[:anni_pagamenti]
          @tipologia_versamenti = session[:tipologia_versamenti]
          @mostra_violazioni = session[:mostra_violazioni]

          debug_message("session[:mostra_violazioni]", 1)
          debug_message(session[:mostra_violazioni], 1)
          debug_message("session[:tipologia_versamenti]", 1)
          debug_message(session[:tipologia_versamenti], 1)

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
    result = HTTParty.get(@dominio+"/get_hash_layout.json", 
      :body => {})
    hash_result = result.parsed_response
    ritornato_hash = false
    if hash_result['esito'] == 'ok'
      ritornato_hash = true
    else
      logger.error "Portale cittadino #{@dominio} non raggiungibile per ottenere hash di layout! Rifaccio chiamata per possibili problemi con Single Thread"
      i = 0
      while ritornato_hash == false && i < 10 
        sleep 1
        result = HTTParty.get(@dominio+"/get_hash_layout.json", 
          :body => {})
        hash_result = result.parsed_response
        if hash_result['esito'] == 'ok'
          ritornato_hash = true
        end
      end
    end  

    if ritornato_hash
        hash_layout = hash_result['hash']
        nome_file = "#{session[:client_id]}_#{hash_layout}.html.erb"
        #cerco if file di layout se presente uso quello
        if Dir["#{Rails.root}/app/views/layouts/layout_portali/#{session[:client_id]}_#{hash_layout}.*"].length == 0
            #scrivo il file
            #cancello i vecchi file con stesso client_id (della stesa installazione)
            Dir["#{Rails.root}/app/views/layouts/layout_portali/#{session[:client_id]}_*"].each{ |vecchio_layout|
              File.delete(vecchio_layout) 
            }
            #richiedo il layout dal portale, questa non dovrebbe avere problemi di single thread in quanto va a prendere html da sessione sul portale
            result = HTTParty.get(@dominio+"/get_html_layout.json", :body => {})
            hash_result = result.parsed_response
            html_layout = Base64.decode64(hash_result['html'])
            #Aggiungo variabile per disabilitare Function.prototype.bind in portal.x.js
            js_da_iniettare = '<script type="text/javascript">window.appType = "external";</script>'
            #Devo iniettare nel layout gli assets e lo yield
            head_da_iniettare = "<%= csrf_meta_tags %>
            <%= csp_meta_tag %>
            <%= stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track': 'reload' %>"
            html_layout = html_layout.gsub("</head>", head_da_iniettare+"</head>").gsub("id=\"portal_container\">", "id=\"portal_container\"><%=yield%>")
            html_layout = html_layout.sub("<script",js_da_iniettare+" <script")
            #parte che include il js della parte react sul layout CHE VA ALLA FINE, ALTRIMENTI REACT NON VA
            html_layout = html_layout.gsub("</body>","<%= javascript_pack_tag 'app_tributi' %> </body>")
                       
            # doc_html = Nokogiri::HTML.parse(html_layout)
            # doc_html.at_css("head").add_next_sibling(head_da_iniettare)
            # doc_html.at_css("#portal_container").add_child("<div id=\"tributi_main\"><%=yield%></div>")
            path_dir_layout = "#{Rails.root}/app/views/layouts/layout_portali/"
            File.open(path_dir_layout+nome_file, "w") { |file| file.puts html_layout.force_encoding(Encoding::UTF_8).encode(Encoding::UTF_8) }
        end
    else
      redirect_to @dominio+"/?err=no_hash"
    
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

    

    if !result["result"].nil? && result["result"].length > 0
      session[:token] = result["result"]["token"]
    end
    
    render :json => result
  end  
  
  def soggetto
    debug_message("soggetto",1)
    params[:data][:tipoRicerca] = "RicercaPerCodiceFiscale"
    params[:data][:codiceFiscale] = session[:cf]
    debug_message(params,1)
    result = HTTParty.get("#{@@api_url}soggetti/GetSoggettiTributi?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" },
    :debug_output => @@log_to_output && @@log_level>2 ? $stdout : nil )    
    
    debug_message(result,1)
    if !result["result"].nil? && result["result"].length > 0
      session[:identificativoSoggetto] = result["result"]["identificativoSoggetto"]
      session[:cognome] = result["result"]["cognome"].strip
      session[:nome] = result["result"]["nome"].strip
    end
    
    render :json => result    
  end
  
  #BOOKMARK immobili tari
  def tari_immobili
    params[:data][:tipoRicerca] = "RicercaPerSoggetto"
    params[:data][:identificativoSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}occupazioni/GetOccupazioni?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    tabellaTasi = []
    if !result["result"].nil? && result["result"].length > 0
      result["result"].each do |value|
        resultIndirizzo = HTTParty.get("#{@@api_url}immobiliTributi/GetIndirizziImmobiliTributi?v=1.0&request[tipoRicerca]=RicercaPerNumeroUtenza&request[numeroUtenza]=#{value['numeroUtenza']}", 
        :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
        
        
        isDomestica = !value['domestica'].nil? && value['domestica']=="Si"
        domestica = isDomestica ? "Domestica":"Non domestica"
        listaNucleoFamCorrenti = []
        listaNucleoFamPrecenti = []
        debug_message("params[:data][:anno]",3)
        debug_message(params[:data][:anno],3)
        value["listaNucleoFam"].each do |nucleoFam|
          debug_message("nucleoFam",3)
          debug_message(nucleoFam,3)
          if nucleoFam["datainizio"].to_s.include? params[:data][:anno].to_s
            debug_message("anno is right!",3)
            listaNucleoFamCorrenti << nucleoFam
          end
        end
        value["listaNucleoFam"].each do |nucleoFam|
          debug_message("nucleoFam",3)
          debug_message(nucleoFam,3)
          if nucleoFam["datainizio"].to_s.last(4).to_i < params[:data][:anno].to_i
            listaNucleoFamPrecenti << nucleoFam
          end
        end
        debug_message("listaNucleoFamCorrenti",3)
        debug_message(listaNucleoFamCorrenti,3)
        debug_message("listaNucleoFamPrecenti",3)
        debug_message(listaNucleoFamPrecenti,3)
        componenti = ""
        if isDomestica
          if listaNucleoFamCorrenti.length() > 0
            listaNucleoFamCorrenti.each do |nucleoFam|
              componenti += " - #{nucleoFam["numeroComponenti"]} componenti dal #{nucleoFam["datainizio"]}"
            end
          end
          if listaNucleoFamCorrenti.length() < 2 && listaNucleoFamPrecenti.length() > 0
            componenti += " - #{listaNucleoFamPrecenti[listaNucleoFamPrecenti.length()-1]["numeroComponenti"]} componenti dal #{listaNucleoFamPrecenti[listaNucleoFamPrecenti.length()-1]["datainizio"]}"
          end
        end
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
        if !resultIndirizzo["result"].nil? && !resultIndirizzo["result"][0].nil? && resultIndirizzo["result"][0].length > 0
          datiImmobile['indirizzo'] = resultIndirizzo["result"][0]['indirizzoCompleto']
        else
          datiImmobile['indirizzo'] = ""
        end
        if !value['listaImmobile'].nil? && value['listaImmobile'].length > 0 
          if !value["listaImmobile"][0]["foglio"].nil? && !value["listaImmobile"][0]["foglio"].blank?
            datiImmobile['catasto'] = "#{value["listaImmobile"][0]["foglio"]}/#{value["listaImmobile"][0]["numero"]}/#{value["listaImmobile"][0]["subalterno"]}";
          else
            datiImmobile['catasto'] = ""
          end
          if datiImmobile['indirizzo'] == "" && !value["listaImmobile"][0]["indirizzo"].nil? && !value["listaImmobile"][0]["indirizzo"].blank?
            datiImmobile['indirizzo'] = value["listaImmobile"][0]["indirizzo"]
          end
        else
          datiImmobile['catasto'] = ""
        end

        if !value['listaRiduzioneOccupazione'].nil? && value['listaRiduzioneOccupazione'].length > 0
          datiImmobile['riduzioniApplicate'] = value['listaRiduzioneOccupazione'][0]['riduzione']['descrizione']
        else 
          datiImmobile['riduzioniApplicate'] = ""
        end

        datiImmobile['id'] = Digest::SHA1.hexdigest(datiImmobile.map{|v| v.to_s.inspect}.join(', '))
        tabellaTasi << datiImmobile
      end
    end
    tabellaTasi = tabellaTasi.sort_by { |hsh| hsh[:catasto] }
    
    render :json => tabellaTasi    
  end
  
  # BOOKMARK pagamenti tari
  def tari_pagamenti
#     params[:data][:idSoggetto] = session[:identificativoSoggetto]
      
    tabellaTasi = []
    
    for anno in (Date.current.year-session[:anni_pagamenti])..Date.current.year do
      result = HTTParty.get("#{@@api_url}avvisiPagamento/GetAvvisiPagamento?v=1.0&request[idSoggetto]=#{session[:identificativoSoggetto]}&request[anno]=#{anno}", 
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
      
      if !result["result"].nil? && result["result"].length > 0
        result["result"].each do |value|
          if (value['dataAnnullamento'].blank?) && value["importoResiduo"].gsub(',', '.').to_f>0 && ( value["statoEmissione"] == "Emesso - Validato" || value["statoEmissione"] == "Validato" )
            statoPagamenti = stato_pagamento("#{session[:dominio].gsub("https","http")}/servizi/pagamenti/ws/stato_pagamenti",value["idAvviso"])
#             statoPagamento = stato_pagamento(value["idAvviso"])
            # Pagato - Pendente - Da Ricaricare - In Attesa RT - Annullato - Non Eseguito - Decorrenza termini - Eliminato d'Ufficio, Avviato
            if(!statoPagamenti.nil? && statoPagamenti["esito"]=="ok" && (statoPagamenti["esito"][0]["stato"]=="Pagato"))
              # pagamento ok, non lo mettiamo in lista
            else
              dettagliRata = HTTParty.get("#{@@api_url}avvisiPagamento/GetDettaglioRate?v=1.0&idAvvisoPagamento=#{value["idAvviso"]}&idCodiceTributoF24=25&anno=#{anno}", 
              :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
              stringaPagamenti = ""
              if !dettagliRata["result"].nil? && dettagliRata["result"].length > 0
                stringaPagamenti = '<ul class="elencoRate">'
                dettagliRata["result"].each do |dettaglioRata|
                  if dettaglioRata["codiceRataF24"] != "0101"
                    stringaPagamenti += "<li>Tributo #{dettaglioRata["codiceTributoF24"]} - rata #{dettaglioRata["codiceRataF24"]} - anno #{anno} - importo &euro;#{dettaglioRata["importo"]} - scadenza #{dettaglioRata["dataScadenza"]}</li>"
                  end
                end
                stringaPagamenti += "</ul>"
              end
              puts stringaPagamenti

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
              tabellaTasi << {"descrizioneAvviso": "#{value["codiceAvvisoDescrizione"]} - n.#{value["numeroAvviso"]} del #{formatted_date} #{stringaPagamenti}", "importoEmesso": value["importoTotale"], "importoPagato": value["importoVersato"], "importoResiduo": value["importoResiduo"], "azioni": azioni}
            end
          end
        end
      end
    end
    
    render :json => tabellaTasi    
  end
  
  #BOOKMARK immobili imutasi
  def imutasi_immobili
    params[:data][:tipoRicerca] = "RicercaPerSoggetto"
    params[:data][:identificativoSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}titolarita/GetTitolarita?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    caratteristiche = ['','Terreno', 'Area edificabile', 'Fabbricato', 'Fabbricato a valore contabile']
    subCaratteristiche = ['','Abitazione principale', 'Pertinenza', 'Rurale', 'Bene merce']
    
    tabellaImu = []
    tabellaTasi = []
    counterImu = 1
    counterTasi = 1
    if !result["result"].nil? && result["result"].length > 0
      result["result"].each do |value|
        
        date_start = DateTime.parse(value["dataInizio"])
        formatted_date_start = date_start.strftime('%d/%m/%Y')
        date_end = DateTime.parse(value["dataFine"])
        formatted_date_end = date_end.strftime('%d/%m/%Y')
        
        stringavalidita = "dal #{formatted_date_start}"
        if date_end.strftime('%Y') != "9999"
          stringavalidita = "dal #{formatted_date_start} al #{formatted_date_end}"
        end
        
        caratteristica = ""
        if !value["caratteristicaTitolarita"].nil?
          caratteristica = caratteristiche[value["caratteristicaTitolarita"]]
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

        catasto = caratteristica
        if value["listaImmobileTributi"][0]["foglio"]
          catasto = "#{catasto}<br>" if !value["caratteristicaTitolarita"].nil?
          catasto = "#{catasto}#{value["listaImmobileTributi"][0]["foglio"]}/#{value["listaImmobileTributi"][0]["numero"]}/#{value["listaImmobileTributi"][0]["subalterno"]}";
        end

        categoria = subCaratteristica
        if !value["categoriaCatastale"].nil?
          categoria = "#{categoria}<br>" if !value["subCaratteristica"].nil?
          categoria = "#{categoria}#{value["categoriaCatastale"]["codice"]}";
        end
          
        datiImmobile = { 
          "rendita": value["rendita"], 
          "validita": stringavalidita,
          "categoria": categoria,
          "aliquota": !value["aliquota"].nil? ? value["aliquota"]["descrizione"] : "",
          "catasto": catasto,
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
  
  #BOOKMARK versamenti
  def versamenti
    tabellaImu = [] 
    counterVersamenti = 1

    labels = { 
      'Ici-Imu' => 'IMU',
      'Tasi' => 'TASI',
      'Tares-Tari' => 'TARI',
      'Imposta Municipale Propria' => 'IMU',
      'Tributo Servizi Indivisibili' => 'TASI',
      'Tassa Rifiuti' => 'TARI'
    }
      
    # commentato perchè su albignasego restituiva valori doppi (presenti anche su versamentiTributi/GetVersamenti)
    #
    # result = HTTParty.get("#{@@api_url}versamentiF24/GetVersamentiF24?v=1.0&codiceFiscale=#{session[:cf]}",
    # :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } )  
  
    # if !result["result"].nil? && result["result"].length > 0
    #   result["result"].each do |value|
    #     tabellaImu << {
    #       "imposta": value["desImposta"],
    #       "dataVersamento": value["dataRiscossione"],
    #       "annoRiferimento": value["annoRiferimento"],
    #       "tipo": "F24",
    #       "codiceTributo": value["codiceTributo"],
    #       "acconto": value["acconto"],
    #       "saldo": value["saldo"],
    #       "detrazione": value["detrazione"],
    #       "totale": value["importoDebito"],
    #       "ravvedimento": value["ravvedimento"],
    #       "violazione": value["violazione"]
    #     }
    #   end
    # end
    
    for anno in (Date.current.year-session[:anni_versamenti])..Date.current.year do
      # serve davvero farlo una volta per imposta? verificare con dati reali
#       result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}&imposta=IciImu", 
#       result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}",
      result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}",
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" },
      :debug_output => @@log_to_output && @@log_level>2 ? $stdout : nil )  
    
      #if result.is_a?(Array) && !result["result"].nil? && result["result"].length > 0
      if !result["result"].nil? && result["result"].length > 0
        result["result"].each do |value|
          rata = value["rata"].blank? ? value["dettaglioRata"] : value["rata"]
          rata = "" if rata.to_s == "0"
          if session[:mostra_violazioni] || (!session[:mostra_violazioni] && !value["violazione"])
            tabellaImu << {
              "id": "getVersamenti"+counterVersamenti.to_s,
              "imposta": labels[value["modulo"]],
              "dataVersamento": value["dataPagamento"],
              "annoRiferimento": value["anno"],
              # "tipo": value["tipoVersamento"].to_s=="2" || value["tipoVersamento"].to_s=="Violazione" ? "Violazione" : "Ordinario" ,
              "tipo": "GetVersamenti",
              "codiceTributo": value["codiceTributoF24"].gsub(/[^0-9]/,""),
              "rata": rata,
              "detrazione": value["importoDetrazione"],
              "totale": value["importo"],
              "ravvedimento": value["rrOo"],
              "violazione": value["violazione"]
            }
            counterVersamenti = counterVersamenti+1
          end
        end
      end
      
      result2 = HTTParty.get("#{@@api_url}versamentiMultiCanale/GetVersamentiMultiCanale?v=1.0&codiceFiscale=#{session[:cf]}&annoRiferimento=#{anno}&tipologia=#{session[:tipologia_versamenti]}", 
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" },
      :debug_output => @@log_to_output && @@log_level>2 ? $stdout : nil )  
    
      if !result2["result"].nil? && result2["result"].length > 0
        result2["result"].each do |value|
          rata = value["rata"]
          rata = "" if rata.to_s == "0"
          violazione = value["tipoVersamento"].to_s=="2" || value["tipoVersamento"].to_s=="Violazione"
          if session[:mostra_violazioni] || (!session[:mostra_violazioni] && !violazione)
            tabellaImu << {
              "id": "getVersamentiMulticanale"+counterVersamenti.to_s,
              "imposta": labels[value["desImposta"]],
              "dataVersamento": value["dataPagamento"],
              "annoRiferimento": value["anno"].to_s.strip.to_i,
              # "tipo": value["tipoVersamento"].to_s=="2" || value["tipoVersamento"].to_s=="Violazione" ? "Violazione" : "Ordinario",
              "tipo": "GetVersamentiMultiCanale",
              "codiceTributo": value["codiceTributo"].gsub(/[^0-9]/,""),
              "rata": rata,
              "detrazione": 0,
              "totale": value["importo"],
              "ravvedimento": value["ravvedimento"],
              "violazione": violazione
            }
            counterVersamenti = counterVersamenti+1
          end
        end
      end            
      
    end

    tabellaImu = tabellaImu.sort_by { |hsh| hsh[:annoRiferimento] }.reverse
    
    render :json => tabellaImu    
  end
  
  # BOOKMARK pagamenti
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
    
    for anno in (Date.current.year-session[:anni_pagamenti])..Date.current.year do
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
      
      if !result["result"].nil? && result["result"].length > 0   
        
        result["result"].each_with_index do |value, i|
          # puts value
          # puts "totaleImportoDovuto is "+string_to_float(value["totaleImportoDovuto"]).to_s
          ravvedimento = value["giorniRitardoRavvedimento"].to_i > 0
          totale = string_to_float(value["totaleImportoDovuto"])
          importoNonZero = string_to_float(value["totaleImportoDovuto"]) > 0
          # puts "importoNonZero? "+importoNonZero.to_s
          is_acconto = value["rata"]=="Acconto"
          has_saldo = !result["result"][i+1].nil? && result["result"][i+1]["rata"]=="Saldo"
          versato_eccesso = has_saldo && string_to_float(result["result"][i+1]["importoVersato"]) > string_to_float(result["result"][i+1]["importoVersatoConsiderato"]) && string_to_float(result["result"][i+1]["totaleImportoDovuto"]) > 0
          # if anno == 2019
          #   puts "-------------------"
          #   puts "value:"
          #   puts value
          #   puts "is_acconto? "+is_acconto.to_s
          #   puts "has_saldo? "+has_saldo.to_s
          #   puts "versato_eccesso? "+versato_eccesso.to_s
          #   puts "importoNonZero? "+importoNonZero.to_s
          #   puts 'value["totaleImportoDovuto"]'+string_to_float(value["totaleImportoDovuto"]).to_s
          #   puts 'result["result"][i+1]["importoVersato"]'+result["result"][i+1]["importoVersato"].to_s
          #   puts 'result["result"][i+1]["importoVersatoConsiderato"]'+result["result"][i+1]["importoVersatoConsiderato"].to_s
          #   puts "result+1? "+(!result["result"][i+1].nil?).to_s
          # end
          compensaSaldo = is_acconto && has_saldo && versato_eccesso
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
            puts "single result is "    
            puts result["result"] 
    
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
                listaF24[anno][value["rata"]]["ravvedimento"] = ravvedimento
                listaF24[anno][value["rata"]]["totaleRavv"] += totale
                listaF24[anno][value["rata"]]["totale"] += totale
                listaF24[anno][value["rata"]]["totaleRavv"] += totale
                listaF24[anno]["Unica"]["totaleRavv"] += totale
                listaF24[anno]["Unica"]["totale"] += totale
                
                log = log+"adding #{value["numeroImmobili"]} to #{stringaNum} for codice tributo #{value["codiceTributo"]} rata #{value["rata"]} anno #{anno} #{value}| "
                
                listaF24[anno][value["rata"]][stringaTributo] += totale
                listaF24[anno][value["rata"]][stringaNum] += value["numeroImmobili"]
                listaF24[anno][value["rata"]]["num"] += value["numeroImmobili"]
                listaF24[anno][value["rata"]]["det"] += string_to_float(value["detrazioneUtilizzata"])
                listaF24[anno][value["rata"]]["dovuto"] += string_to_float(value["totaleImportoDovuto"])
                listaF24[anno][value["rata"]]["versato"] += string_to_float(value["importoVersatoConsiderato"])
                listaF24[anno][value["rata"]]["dovutoPre"] += string_to_float(value["importoDovuto"])
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
            # if anno == 2019
            #   puts "Deleting #{value["rata"]} from #{anno} (!importoNonZero["+importoNonZero.to_s+"] || !compensaSaldo["+compensaSaldo.to_s+"])";
            #   puts 'value["rata"]'
            #   puts value["rata"]
            #   puts "before delete"
            #   puts listaF24[anno]
            # end
            listaF24[anno].tap { |hs| (!hs.nil? && !hs[value["rata"]].nil?) ? hs.delete(value["rata"]) : next }
            # if anno == 2019
            #   puts "after delete"
            #   puts listaF24[anno]
            # end
          end
        end      
      end
      
    end
        
    listaF24.each do |anno, f24|
      puts "parsing F24"
      puts f24
      data_pagamento = DateTime.parse(params[:data][:dataPagamento])
      data_pagamento = data_pagamento.strftime('%d/%m/%Y')
      secret = OpenSSL::Digest::SHA1.new("servizisoap.?/XOa[=pyWVGucbJwCsf3LHF3gBTWO06")

      url_stampa = "belfiore=#{session[:belfiore]}&cognome=#{session[:cognome]}&nome=#{session[:nome]}&appTributi=true&cf=#{session[:cf]}&anno=#{anno}&stampaImposta=#{( params[:data][:modulo]=="Imposta_Immobili" ? "IMU" : "TASI" )}"
      
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
          numRata = nomeRata=="Unica" ? "" : ( nomeRata=="Acconto" ? "1" : "2" )
          datiRata.each do |key, value|
            if key.end_with? "C"
              queryKey = "#{key.chomp("C")}#{numRata}C"
            elsif key.end_with? "T"
              queryKey = "#{key.chomp("T")}#{numRata}T"
            else
              queryKey = "#{key}#{numRata}"
            end
            
            queryKey[0] = queryKey[0].downcase;
            
            if key == "ravvedimento"
              if value
                url_stampa += "&ravv=1&dataRavv=#{data_pagamento}&sanzioni=1"
              end
            else
              if queryKey.match(/^num/) && value.to_i > 0 
                fixQueryKey = queryKey.chomp("C").chomp("T").chomp("1").chomp("2")
                if !url_stampa.include? fixQueryKey
                  url_stampa += "&#{fixQueryKey}=#{value}"
                  puts "adding &#{fixQueryKey}=#{value} to url_stampa"
                end
              elsif !queryKey.match(/^num/)
                url_stampa += "&#{queryKey}=#{value}"
              end
            end
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
            "azioni": "rata=#{nomeRata.downcase}&#{nomeRata.downcase}=true&#{url_stampa_rata}&idc=#{secret}"
          }
          tabellaImu << datiF24
        
        end
        
      end
      
    end
    
#     urls = {"acconto":"#{session[:url_stampa]}?rata=acconto&acconto=true&#{url_stampa}", "saldo":"#{session[:url_stampa]}?rata=saldo&saldo=true&#{url_stampa}"}
    
#     render :json => {"tabella": tabellaImu, "urls": urls, "listaF24": listaF24}
    # render :json => {"log": log, "tabella": tabellaImu, "listaF24": listaF24, "results": results}
    render :json => {"tabella": tabellaImu, "listaF24": listaF24}
#     render :json => {"tabella": tabellaImu, "listaF24": listaF24}
  end
  
  #da fare
  def error_dati
  end
   
  #Va a pulire la sessione e chiama il logout sul portale
  def logout
    url_logout = File.join(session['dominio'],"autenticazione/logout")
    reset_session
    redirect_to url_logout
  end

  private

  def string_to_float(number)
    float = number.gsub(".","").gsub(",",".").to_f    
    return (float*100).round / 100.0
  end

  def debug_message(message, level)
    # puts "debug_message called for message #{message} and level #{level} @@log_level #{@@log_level} @@log_to_file #{@@log_to_file}"
    if level <= @@log_level
      logger.debug message unless !@@log_to_file
      puts message unless !@@log_to_output
    end
  end

  def value_or_default(var, default)
    value = default
    debug_message("value_or_default for var",3)
    debug_message(var,3)
    debug_message(var.nil?,3)
    debug_message(var.blank?,3)
    debug_message(var.to_s,3)
    debug_message(var.to_i,3)
    if !var.nil? && !var.blank? && var.to_s != ""
      if(var == "true") 
        value = true
      elsif(var == "false")
        value = false
      else
        value = var
      end
    end
    return value
  end

end

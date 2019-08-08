require 'httparty'

class ApplicationController < ActionController::Base
  @@api_url = "http://api.civilianextdev.it/Tributi/api/"
  
  #ROOT della main_app
  def index
    @assets = JSON.parse(Base64.decode64(params[:assets].to_s))
    session[:cf] = params[:cf].to_s
    session[:url_stampa] = Base64.decode64(params[:url_stampa].to_s)
    #render :json => session
  end
  
  def authenticate
    result = HTTParty.post("#{@@api_url}utilities/AuthenticationToken?v=1.0", 
    :body => params[:data].to_json,
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
      session[:cognome] = result["result"]["cognome"]
      session[:nome] = result["result"]["nome"]
    end
    
#     result[:test] = "bearer #{session[:token]}"
#     
#     result[:params] = params
#     result[:session] = session
    
    render :json => result    
  end
  
  def tasi_immobili
    params[:data][:tipoRicerca] = "RicercaPerSoggetto"
    params[:data][:identificativoSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}occupazioni/GetOccupazioni?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    tabellaTasi = []
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
        domestica = !value['domestica'].nil? && value['domestica']?"Domestica":"Non domestica"
        datiImmobile = {'tipoTariffa': "#{domestica} - #{value['codiceCategoria']}", "metriQuadri": value['totaleSuperficie'], "validita": "#{value['dataInizio']} - #{value['dataFine']}"}
        if !value['listaImmobile'].nil? && value['listaImmobile'].length>0
          datiImmobile['indirizzo'] = value['listaImmobile'][0]['indirizzo']
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
#         tabellaTasi << {'categoria': value['codiceCategoria'],'indirizzo': value['listaImmobile'][0]['indirizzo'],'catasto': "#{value['listaImmobile'][0]['foglio']}/#{value['listaImmobile'][0]['numero']}/#{value['listaImmobile'][0]['subalterno']}"}
        #@tabellaTasi[key] = value
      end
    end
    
    render :json => tabellaTasi    
  end
  
  def tasi_pagamenti
    params[:data][:idSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}avvisiPagamento/GetAvvisiPagamento?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    tabellaTasi = []
    
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
        if (value['dataAnnullamento'].blank?) && (value['statoEmissione'].include? "Emesso")
          tabellaTasi << {"descrizioneAvviso": "#{value["codiceAvvisoDescrizione"]} - n.#{value["numeroAvviso"]} del #{value["dataAvviso"]}", "importoEmesso": value["importoTotale"], "importoPagato": value["importoVersato"]}
        end
      end
    end
    
    render :json => tabellaTasi    
  end
  
  def imu_immobili
    params[:data][:tipoRicerca] = "RicercaPerSoggetto"
    params[:data][:identificativoSoggetto] = session[:identificativoSoggetto]
    result = HTTParty.get("#{@@api_url}titolarita/GetTitolarita?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    tabellaImu = []
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
        datiImmobile = { 
          "rendita": value["rendita"], 
          "validita": "#{value["dataInizio"]} - #{value["dataFine"]}",
          "categoria": value["categoriaCatastale"]["codice"],
          "aliquota": value["aliquota"],
          "catasto": "#{value["listaImmobileTributi"][0]["foglio"]}/#{value["listaImmobileTributi"][0]["numero"]}/#{value["listaImmobileTributi"][0]["subalterno"]}",
          "indirizzo": value["listaImmobileTributi"][0]["indirizzo"]
        }
        if !value["tipoTitolarita"].nil? && value["tipoTitolarita"].length>0     
          datiImmobile['possesso'] = "#{value["percentualePossesso"]}% #{value["tipoTitolarita"]["descrizione"]}"
        end
        riduzioni = []
        if value['storico']
          riduzioni << "storico"
        end
        if value['inagibile']
          riduzioni << "inagibile"
        end
        if value['esenteEscluso']
          riduzioni << "esente"
        end
        datiImmobile['riduzioni'] = riduzioni.join(" - ")
        tabellaImu << datiImmobile
      end
    end
    
    
    render :json => tabellaImu    
  end
  
  def imu_pagamenti
    tabellaImu = []
    for anno in 2012..2019 do
      result = HTTParty.get("#{@@api_url}versamentiTributi/GetVersamenti?v=1.0&idSoggetto=#{session[:identificativoSoggetto]}&annoRiferimento=#{anno}", 
      :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } )  
    
      if !result["result"].nil? && result["result"].length>0
        result["result"].each do |value|
          tabellaImu << {
            "dataVersamento": value["dataRiscossione"],
            "annoRiferimento": value["annoRiferimento"],
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
    end 
    
    render :json => tabellaImu    
  end
   
  def imu_ravvedimento
    params[:data][:modulo] = "Imposta_Immobili"
    params[:data][:idSoggetto] = session[:identificativoSoggetto]
    url = "#{@@api_url}importiPreliquidati/GetDettaglioPreliquidato?v=1.0&#{params[:data].to_unsafe_h.to_query}"
    result = HTTParty.get("#{@@api_url}importiPreliquidati/GetDettaglioPreliquidato?v=1.0&#{params[:data].to_unsafe_h.to_query}", 
    :headers => { 'Content-Type' => 'application/json','Accept' => 'application/json', 'Authorization' => "bearer #{session[:token]}" } ) 
    
    tabellaImu = []
    f24 = {"Acconto"=>{"totale"=>0,"det"=>0},"Saldo"=>{"totale"=>0,"det"=>0},"Unica"=>{"totale"=>0,"det"=>0, "num"=>0}}
    codiciTributo = {
      "3912"=> "abitazione",
      "3913"=> "rurali",
      "3914"=> "terreniC",
      "3915"=> "terreniC",
      "3916"=> "areeC",
      "3917"=> "areeC",
      "3918"=> "altriC",
      "3919"=> "altriC",
      "3930"=> "prodC",
      "3925"=> "prod",
      "3958"=> "abitazioneT",
      "3959"=> "ruraliT",
      "3960"=> "areeT",
      "3961"=> "altriT"
    }
    codiciTributo.each do |codice, stringaTributo| 
      stringaNum = "#{stringaTributo}"
      stringaNum[0] = stringaNum[0,1].upcase
      stringaNum = "num#{stringaNum}"

      f24["Unica"][stringaTributo] = 0
      f24["Unica"][stringaNum] = 0
      f24["Acconto"][stringaTributo] = 0
      f24["Acconto"][stringaNum] = 0
      f24["Saldo"][stringaTributo] = 0
      f24["Saldo"][stringaNum] = 0
    end
    if !result["result"].nil? && result["result"].length>0
      result["result"].each do |value|
      totale = value["totaleImportoDovuto"].gsub(',', '.').to_f
        datiF24 = { 
          "codiceTributo": value["codiceTributo"], 
          "rata": value["rata"], 
          "importoVersato": value["importoVersato"], 
          "totaleImportoDovuto": value["totaleImportoDovuto"], 
          "numeroImmobili": value["numeroImmobili"], 
        }
        tabellaImu << datiF24
        if totale>0
          stringaTributo = codiciTributo[value["codiceTributo"]]
          stringaNum = "#{stringaTributo.chomp("C")}"
          stringaNum[0] = stringaNum[0,1].upcase
          stringaNum = "num#{stringaNum}"
          if f24[value["rata"]][stringaNum].nil?
            f24[value["rata"]][stringaNum] = 0
          end
          if !value["rata"].nil? && !f24.nil? && !f24[value["rata"]].nil?
            f24[value["rata"]]["totale"] += totale
            
            f24[value["rata"]][stringaTributo] += totale
            f24[value["rata"]][stringaNum] += value["numeroImmobili"]
            f24[value["rata"]]["det"] += value["detrazioneUtilizzata"].gsub(',', '.').to_f
            f24["Unica"]["totale"] += totale
            if value["rata"] == "Acconto" 
              f24["Unica"]["num"] += value["numeroImmobili"]
              f24["Unica"][stringaNum] = value["numeroImmobili"]
            end
           
            f24["Unica"][stringaTributo] += totale
          end
        end
      end
    end
    
    url_stampa = "ravv=1&dataRavv=#{params[:data][:dataPagamento]}&cognome=#{session[:cognome]}&nome=#{session[:nome]}&appTributi=true&cf=#{session[:cf]}&anno=#{params[:data][:anno]}&stampaImposta=IMU&totale=#{f24['totale']}&det=#{f24["det"]}&num=#{f24["num"]}&sanzioni=1"
    f24.each do |nomeRata, datiRata|
      numRata = ""
      if nomeRata == "Acconto" || nomeRata == "Saldo"
        numRata = nomeRata=="Acconto"?"1":"2"
      end
      datiRata.each do |key, value|
        if key.end_with? "C"
          queryKey = "#{key.chomp("C")}#{numRata}C"
        elsif key.end_with? "T"
          queryKey = "#{key.chomp("T")}#{numRata}T"
        else
          queryKey = "#{key}#{numRata}"
        end
        
        url_stampa += "&#{queryKey}=#{value}"
      end
    end
    
    urls = {"acconto":"#{session[:url_stampa]}?rata=acconto&acconto=true&#{url_stampa}", "saldo":"#{session[:url_stampa]}?rata=saldo&saldo=true&#{url_stampa}"}
    
    render :json => {"tabella": tabellaImu, "urls": urls, "f24": f24}
  end
  
  #da fare
  def error_dati
  end
    
end

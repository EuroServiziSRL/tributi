require 'httparty'
module ApplicationHelper
  
  def stato_pagamento(idAvviso)
    headers = { 'client_id' => 'uin892IO!', 
      'req_time' => Time.now.strftime("%d%m%Y%H%M%S"), 
      'applicazione' => 'tributi', 
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
    
    headers['check'] = Digest::SHA1.hexdigest("sKd80O12nmclient_id=#{headers["client_id"]}&req_time=#{headers["req_time"]}&applicazione=#{headers["applicazione"]}")
    
    result = headers
    result = HTTParty.post("http://civilianext.soluzionipa.it/portal/servizi/pagamenti/ws/stato_pagamenti", 
    :body => "[{'id_univoco_dovuto': '#{idAvviso}'}]",
    :headers => headers ) 
    return result
  end
  
end

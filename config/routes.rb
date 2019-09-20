Rails.application.routes.draw do
  get 'error_dati' => "application#error_dati", :as => :error_dati
  
  get '/' => 'application#index', :as => :index
  post 'api_call' => 'application#api_call', :as => :api_call
  get 'api_post' => 'application#api_post', :as => :api_post
  get 'api_get' => 'application#api_get', :as => :api_get
  get 'authenticate' => 'application#authenticate', :as => :authenticate
  get 'soggetto' => 'application#soggetto', :as => :soggetto
  get 'tari_immobili' => 'application#tari_immobili', :as => :tari_immobili
  get 'tari_pagamenti' => 'application#tari_pagamenti', :as => :tari_pagamenti
  get 'imutasi_immobili' => 'application#imutasi_immobili', :as => :imutasi_immobili
  get 'versamenti' => 'application#versamenti', :as => :versamenti
  get 'imutasi_pagamenti' => 'application#imutasi_pagamenti', :as => :imutasi_pagamenti
  
  get 'sconosciuto' => 'application#sconosciuto', :as => :sconosciuto
  root to: "application#index"
end

Rails.application.routes.draw do
  get 'error_dati' => "application#error_dati", :as => :error_dati
  
  get '/' => 'application#index', :as => :index
  post 'api_call' => 'application#api_call', :as => :api_call
  get 'api_post' => 'application#api_post', :as => :api_post
  get 'api_get' => 'application#api_get', :as => :api_get
  get 'authenticate' => 'application#authenticate', :as => :authenticate
  get 'soggetto' => 'application#soggetto', :as => :soggetto
  get 'tasi_immobili' => 'application#tasi_immobili', :as => :tasi_immobili
  get 'tasi_pagamenti' => 'application#tasi_pagamenti', :as => :tasi_pagamenti
  get 'imu_immobili' => 'application#imu_immobili', :as => :imu_immobili
  get 'imu_pagamenti' => 'application#imu_pagamenti', :as => :imu_pagamenti
  get 'imu_ravvedimento' => 'application#imu_ravvedimento', :as => :imu_ravvedimento
  
  root to: "application#index"
end

Cased::Rails::Engine.routes.draw do
  get '/authorizations/callback' => 'cased/authorizations#create', as: :authorizations
  delete '/logout' => 'cased/authorizations#destroy', as: :logout
  get '/cli/sessions/:guard_session_id' => 'cased/cli/sessions#show', as: :guard_session
  post '/cli/sessions/:guard_session_id/cancel' => 'cased/cli/sessions#cancel', as: :cancel_guard_session
end

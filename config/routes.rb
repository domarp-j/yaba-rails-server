# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'

  scope 'api' do
    get 'health-check', to: 'health_check#new'

    # TODO: Make more RESTful

    scope 'transaction-items' do
      get '/', to: 'transaction_items#index', as: 'transaction_items'
      post '/', to: 'transaction_items#create', as: 'add_transaction_item'
    end

    scope 'transaction-item' do
      post '/update', to: 'transaction_items#update', as: 'update_transaction_item'
      post '/delete', to: 'transaction_items#destroy', as: 'delete_transaction_item'
    end

    scope 'tags' do
      post '/', to: 'tags#create', as: 'add_tag'
      post '/delete', to: 'tags#destroy', as: 'destroy_tag'
    end
  end
end

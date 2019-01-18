# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'

  scope 'api' do
    get 'health-check', to: 'health_check#new'

    scope 'transaction-items' do
      get '/', to: 'transaction_items#index', as: 'transaction_items'
      post '/', to: 'transaction_items#create', as: 'add_transaction_item'
      get '/csv', to: 'csv#index', as: 'transaction_items_csv'

      scope ':transaction_id/tags' do
        post '/', to: 'tag_transactions#create', as: 'add_tag_transaction'
        post '/update', to: 'tag_transactions#update', as: 'update_tag_transaction'
        post '/delete', to: 'tag_transactions#destroy', as: 'destroy_tag_transaction'
      end
    end

    scope 'transaction-item' do
      post '/update', to: 'transaction_items#update', as: 'update_transaction_item'
      post '/delete', to: 'transaction_items#destroy', as: 'delete_transaction_item'
    end

    scope 'tags' do
      get '/', to: 'tags#index', as: 'tags'
    end
  end
end

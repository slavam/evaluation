Evaluation::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.
  resources :blocks do
    collection do
      get :new_block, :edit_weights
      post :save_weights, :save_updated_weights
    end
  end
  resources :factors do
    collection do
      get :new_factor, :edit_weights
      post :save_weights, :save_updated_weights
    end
  end
  resources :factor_descriptions

#    collection do
#      get :show_values, :show_factors_by_template
#    end
#  end
  resources :directions do
    collection do
      get :show_eigen_blocks, :show_eigen_factors, :show_articles
    end
  end
#  resources :workers
#  resources :weight_factors
  resources :performances do
    collection do
      get :get_report_params, :report_print, :get_calc_params, :calc_kpi, :show_report, :show_values
    end
  end

  resources :workers do
    collection do
      get :my_show
    end
  end
  resources :subdivisions do
    collection do
      get :my_show
    end
  end
  resources :businesses
  resources :actions
#  resources :branch_of_banks

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "directions#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end

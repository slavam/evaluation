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
      get :new_factor, :edit_weights, :edit_descriptor
      post :save_weights, :save_updated_weights, :save_descriptor
    end
  end
  resources :factor_descriptions

#    collection do
#      get :show_values, :show_factors_by_template
#    end
#  end
  resources :directions do
    collection do
      get :show_eigen_blocks, :show_eigen_factors, :show_articles, :category_select, :show_factors
    end
  end

  resources :fixations do
    collection do
      get :get_master, :show_workers_by_master
    end
  end
  resources :branch_of_banks
  resources :performances do
    collection do
      get :get_report_params, :get_report_params_2, :get_report_division, 
        :report_print, :get_calc_params, :get_calc_division, 
        :calc_kpi, :show_report, :show_values, :get_calc_worker, :get_report_worker, 
        :show_kpi_by_divisions, :show_final_kpi, :show_final_kpi_for_division,
        :show_final_kpi_for_direction
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
  resources :divisions
  resources :levels
#  match '/values/destroy', :controller => 'values', :action => 'destroy'


  resources :values do
#    delete :destroy, :on => :member
    collection do
      get :add_data_by_division, :add_data_by_worker, :show_values_by_factor, :delete_value
      post :save_value
#      delete :delete_value
    end
  end
#  match '/destroy' => "values#destroy", :as => "destroy"
  
  resources :articles do
    collection do
      get :new_article
      post :save_article
    end
  end

  resources :params do
    collection do
      get :show_params_by_factor, :new_param, :destroy
      post :save_param
    end
  end

  resources :param_descriptions
  resources :problem_rates do
    collection do
      get :delete_interval, :new_interval
    end
  end

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
#  root :to => "directions#index"
  root :to => "performances#get_report_params"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end

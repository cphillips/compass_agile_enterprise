ErpInventory::Engine.routes.draw do

  # Routes for default Inventory Management Applications

  namespace 'erp_app' do
    namespace 'organizer' do
      namespace 'asset_management' do
        resources 'fixed_assets'
        resources 'facilities'
        get 'facilities/show_summary(/:id)' => 'facilities#show_summary'
      end
      namespace 'inventory_mgt' do
        resources :inventory_entries
        resources :inventory_entry_locations
        get 'inventory_entries/show_summary(/:id)' => 'inventory_entries#show_summary'
      end
    end
  end

  match '/erp_app/organizer/inventory_mgt/menu' => 'erp_app/organizer/inventory_mgt/base#menu'
  match '/erp_app/organizer/inventory_mgt/inventory_txns(/:action(/:id))' => 'erp_app/organizer/inventory_mgt/inventory_txns'

end

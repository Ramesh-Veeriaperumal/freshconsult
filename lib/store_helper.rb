module StoreHelper # Datas to be exposed to clientside
  
  def get_store_data
    agentslist = current_account.agents_details_from_cache
    @agents_list ||= agentslist.inject([]) do |res,agent|
      res << {:id => agent.id, :name => agent.name, :is_account_admin => agent.email == current_account.admin_email}
    end

    @groups_list ||= current_account.groups_from_cache.inject([]) do |res,group|
      res << {:id => group.id, :name => group.name}
    end

    @products_list ||= current_account.products_from_cache.inject([]) do |res,product|
      res << {:id => product.id, :name => product.name}
    end

    @features_list ||= current_account.features_list

    {:current_user => current_user, :agent => @agents_list, :group => @groups_list, :product => @products_list, :features_list => @features_list, :agents_count => agentslist.count}.to_json
  end
end
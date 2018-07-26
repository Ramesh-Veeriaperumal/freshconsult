module StoreHelper
  
  def get_store_data
    get_agent_list
    get_group_list

    @products_list ||= current_account.products_from_cache.inject([]) do |res,product|
      res << {:id => product.id, :name => product.name}
    end

    @features_list ||= current_account.features_list

    {:current_user => current_user, :agent => @agents_list, :group => @groups_list, :product => @products_list, :features_list => @features_list, :agents_count => @agents_list.count}.to_json
  end


  def get_portal_store_data
    ticket_fields = current_account.ticket_fields_from_cache.select do |field| 
      ['agent','group'].include?(field.name) && field.editable_in_portal
    end
    ticket_fields.each { |fd| safe_send("get_#{fd.name}_list") }

    { agent: @agents_list || [], group: @groups_list || [] }.to_json
  end


  def get_agent_list
    agentslist = current_account.agents_details_from_cache
    @agents_list ||= agentslist.inject([]) do |res,agent|
      res << { id: agent.id, name: agent.name, is_account_admin: agent.email == current_account.admin_email}
    end
  end

  def get_group_list
    @groups_list ||= current_account.groups_from_cache.inject([]) do |res,group|
      res << { id: group.id, name: group.name }
    end
  end
end
module RolesSandboxHelper
  MODEL_NAME = Account.reflections["roles".to_sym].klass.new.class.name
  ACTIONS = ['delete', 'update', 'create']

  def roles_data(account)
    all_roles_data = []
    ACTIONS.each do |action|
      all_roles_data << send("#{action}_roles_data", account)
    end
    all_roles_data.flatten
  end

  def create_roles_data(account)
    roles_data = []
    3.times do
      role = create_role( { :privilege_list => ["manage_tickets", "edit_ticket_properties", "view_forums", "view_contacts", 
                              "view_reports", "", "0", "0", "0", "0" ]} )
      roles_data << Hash[role.attributes].merge("model"=>MODEL_NAME, "action"=>"added")
    end
    return roles_data
  end

  def update_roles_data(account)
    role = account.roles.first
    return [] unless role
    role.description = "test update"
    data = role.description.clone
    role.save
    return Hash[data.map {|k,v| [k,v[1]]}].merge("id"=> role.id).merge("model"=>MODEL_NAME, "action"=>"modified")
  end

  def delete_roles_data(account)
    role = account.roles.first
    return [] unless role
    role.destroy
    return Hash[role.attributes].merge("model"=>MODEL_NAME, "action"=>"deleted")
  end

  def create_role(params = {})
    test_role = FactoryGirl.build(:roles, :name => Faker::Name.name, :description => Faker::Lorem.paragraph, 
                                :privilege_list => params[:privilege_list] )
    test_role.save(validate: false)
    test_role
  end

end
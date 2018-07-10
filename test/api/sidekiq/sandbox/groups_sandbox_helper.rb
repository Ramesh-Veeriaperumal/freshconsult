module GroupsSandboxHelper
  MODEL_NAME = Account.reflections["groups".to_sym].klass.new.class.name
  ACTIONS = ['delete', 'update', 'create']

  def groups_data(account)
    all_groups_data = []
    ACTIONS.each do |action|
      all_groups_data << send("#{action}_groups_data", account)
    end
    all_groups_data.flatten
  end

  def create_groups_data(account)
    groups_data = []
    3.times do
      group = create_group(account)
      groups_data << Hash[group.attributes].merge("model"=>MODEL_NAME, "action"=>"added")
    end
    groups_data
  end

  def update_groups_data(account)
    group = account.groups.reload
    return [] unless group
    group = group[0]
    group.name = "update test"
    data = group.changes.clone
    group.save 
    Hash[data.map {|k,v| [k,v[1]]}].merge("id"=> group.id,"model"=>MODEL_NAME, "action"=>"modified")
  end

  def delete_groups_data(account)
    group = account.groups.reload
    return [] unless group
    group = group[0]
    group.destroy
    Hash[group.attributes].merge("model"=>MODEL_NAME, "action"=>"deleted")
  end

  def create_group(account, options= {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
    group = FactoryGirl.build(:group, :name => name)
    group.account_id = account.id
    group.save!
    group
  end
end

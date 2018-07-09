module SlaPoliciesSandboxHelper
  MODEL_NAME = Account.reflections["sla_policies".to_sym].klass.new.class.name
  ACTIONS = ['delete', 'update', 'create']

  def sla_policies_data(account)
    all_sla_policies_data = []
    ACTIONS.each do |action|
      all_sla_policies_data << send("#{action}_sla_policies_data", account)
    end
    all_sla_policies_data.flatten
  end

  def create_sla_policies_data(account)
    sla_policies_data = []
    3.times do
      test_sla_policy = create_sla_policies(account)
      sla_policies_data << test_sla_policy.attributes.merge("model" => MODEL_NAME, "action" => "added")
    end
    return sla_policies_data
  end

  def update_sla_policies_data(account) 
    sla_policy = account.sla_policies.where(is_default: false).last 
    return [] unless sla_policy
    sla_policy.update_attributes({:name => "test_update_sla_policy_1"})
    changed_attr = sla_policy.changes
    sla_policy.save(validate: false)
    return [Hash[changed_attr.map {|k,v| [k,v[1]]}].merge("id"=> sla_policy.id).merge("model" => MODEL_NAME, "action" => "modified")]
  end

  def delete_sla_policies_data(account)
    sla_policy = account.sla_policies.where(is_default: false).last
    return [] unless sla_policy
    sla_policy.destroy
    return [sla_policy.attributes.merge("model" => MODEL_NAME, "action" => "deleted")]
  end

  def create_sla_policies(account)
    existing_policies_count = account.sla_policies.length
    customer = FactoryGirl.build(:customer, :name => Faker::Name.name)
    customer.save
    sla_policy = FactoryGirl.build(:sla_policies, :name => Faker::Name.name, 
      :description => Faker::Lorem.paragraph, :account_id => account.id,
      :position => existing_policies_count + 1, 
      :datatype => {:ticket_type => "text"})
    sla_policy.account = account
    sla_policy.save(validate: false)
    sla_policy
  end

end
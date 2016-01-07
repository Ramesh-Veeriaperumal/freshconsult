module AutomationsHelper
  include VAConfig

  def create_scn_automation_rule (params={})
    va_rule=FactoryGirl.build(:scn_automation, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                          :action_data => [{:name=> "priority", :value=>"3"}],
                          :account_id=>params[:account_id],
                          :rule_type=>VAConfig::SCENARIO_AUTOMATION)
    va_rule.save(validate: false)
    accessible=va_rule.create_accessible(:access_type=>params[:accessible_attributes][:access_type])
    if(params[:accessible_attributes][:access_type]== Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups])
      accessible.create_group_accesses(params[:accessible_attributes][:group_ids])
    elsif(params[:accessible_attributes][:access_type]== Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users])
      accessible.create_user_accesses(params[:accessible_attributes][:user_ids])
    end
    va_rule
  end

  def create_dispatchr_rule (params={})

    va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                          :action_data => [{:name=> "priority", :value=>"3"}],
                          :filter_data => [{:name=>"ticket_type", :operator=>"in", :value=>["Question", "Problem"]}],
                          :account_id=>params[:account_id],
                          :rule_type=>VAConfig::BUSINESS_RULE)
    va_rule.save(validate: false)
    va_rule

  end

  def create_supervisor_rule (params={})

    va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                          :action_data => [{:name=> "priority", :value=>"3"}],
                          :filter_data => [{:name=>"ticket_type", :operator=>"is", :value=>"Question"}],
                          :account_id=>params[:account_id],
                          :rule_type=>VAConfig::SUPERVISOR_RULE)
    va_rule.save(validate: false)
    va_rule

  end

  def create_observer_rule (params={})

    va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                          :action_data => [{:name=> "priority", :value=>"3"}],
                          :filter_data => {:events=>[{:name=>"priority", :from=>"--", :to=>"--"}],:performer=>{"type"=>"1"},:conditions=>[{:name=>"ticket_type", :operator=>"in", :value=>["Problem", "Question"]}]},
                          :account_id=>params[:account_id],
                          :rule_type=>VAConfig::OBSERVER_RULE)
    va_rule.save(validate: false)
    va_rule

  end

end

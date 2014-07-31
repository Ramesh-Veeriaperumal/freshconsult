require 'spec_helper'

module AutomationsHelper
  include VAConfig

  def create_scn_automation_rule (params={})

    va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                          :action_data => [{:name=> "priority", :value=>"3"}],
                          :account_id=>params[:account_id],
                          :rule_type=>VAConfig::SCENARIO_AUTOMATION)
    va_rule.save(validate: false)
    va_rule

  end

  def create_dispatchr_rule (params={})

    va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                          :action_data => [{:name=> "priority", :value=>"3"}],
                          :filter_data => [{:name=>"ticket_type", :operator=>"is", :value=>"Question"}],
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
                          :filter_data => {:events=>[{:name=>"priority", :from=>"--", :to=>"--"}],:performer=>{"type"=>"1"},:conditions=>[{:name=>"ticket_type", :operator=>"is", :value=>"Problem"}]},
                          :account_id=>params[:account_id],
                          :rule_type=>VAConfig::OBSERVER_RULE)
    va_rule.save(validate: false)
    va_rule

  end

end

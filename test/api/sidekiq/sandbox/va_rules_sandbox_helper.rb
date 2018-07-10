module VaRulesSandboxHelper
  ACTIONS = ['delete', 'update', 'create']

  RULES = ['scenario_automation', 'dispatcher', 'supervisor', 'observer']
  ACTIONS.each do |action|
    define_method "#{action}_va_rules_data" do|account|
      va_rules = []
      RULES.each do|rule, number|
        va_rules << send("#{action}_#{rule}_rule", account)
      end
      va_rules.flatten
    end
  end

  def va_rules_data(account)
    all_va_rules_data = []
    ACTIONS.each do |action|
      all_va_rules_data << send("#{action}_va_rules_data", account)
    end
    all_va_rules_data.flatten
  end

  def create_scenario_automation_rule(account)
    va_rules = []
    3.times do
      va_rule=FactoryGirl.build(:scn_automation,
                                name: "created by #{Faker::Name.name}",
                                description: Faker::Lorem.sentence(2),
                                action_data: [{ name: 'priority', value: '3' }],
                                account_id: account.id,
                                rule_type: VAConfig::SCENARIO_AUTOMATION)

      va_rule.save(validate: false)
      va_rules << [va_rule.attributes.merge({"action" => 'added', "model" => "VaRule"})]
    end
    va_rules.flatten

  end

  def create_dispatcher_rule(account)
    va_rules = []
    3.times do
      va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                                :action_data => [{:name=> "priority", :value=>"3"}],
                                :filter_data => [{:name=>"ticket_type", :operator=>"in", :value=>["Question", "Problem"]}],
                                :account_id=>account.id,
                                :rule_type=>VAConfig::BUSINESS_RULE)
      va_rule.save(validate: false)
      va_rules << [va_rule.attributes.merge({"action" => 'added', "model" => "VaRule"})]
    end

    va_rules.flatten
  end

  def create_supervisor_rule(account)
    va_rules = []
    3.times do
      va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                                :action_data => [{:name=> "priority", :value=>"3"}],
                                :filter_data => [{:name=>"ticket_type", :operator=>"is", :value=>"Question"}],
                                :account_id=>account.id,
                                :rule_type=>VAConfig::SUPERVISOR_RULE)
      va_rule.save(validate: false)
      va_rules << [va_rule.attributes.merge({"action" => 'added', "model" => "VaRule"})]
    end
    va_rules.flatten
  end

  def create_observer_rule(account)
    va_rules = []
    3.times do
      va_rule=FactoryGirl.build(:va_rule, :name=>"created by #{Faker::Name.name}", :description=>Faker::Lorem.sentence(2),
                                :action_data => [{:name=> "priority", :value=>"3"}],
                                :filter_data => {:events=>[{:name=>"priority", :from=>"--", :to=>"--"}],:performer=>{"type"=>"1"},:conditions=>[{:name=>"ticket_type", :operator=>"in", :value=>["Problem", "Question"]}]},
                                :account_id=>account.id,
                                :rule_type=>VAConfig::OBSERVER_RULE)
      va_rule.save(validate: false)
      va_rules << [va_rule.attributes.merge({"action" => 'added', "model" => "VaRule"})]
    end

    va_rules.flatten
  end

  RULES.each do |rule|
    define_method "delete_#{rule}_rule" do|account|
      va_rule = account.account_va_rules.find_by_rule_type(VAConfig::RULES[rule.to_sym])
      return [] unless va_rule
      data = va_rule.attributes.clone
      va_rule.destroy
      [data.merge({"action" => 'deleted', "model" => "VaRule"})]
    end
  end

  RULES.each do |rule|
    define_method "update_#{rule}_rule" do|account|
      va_rule = account.account_va_rules.find_by_rule_type(VAConfig::RULES[rule.to_sym])
      return [] unless va_rule
      va_rule.name = Faker::Name.name
      va_rule.description = Faker::Lorem.sentence(2)
      va_rule.action_data = [{:name=> "priority", :value=>"4"}]
      data = va_rule.changes.clone
      va_rule.save
      [Hash[data.map { |k, v| [k, v[1]] }].merge({"id" =>va_rule.id, "action" => 'modified', "model" => "VaRule"})]
    end
  end
end
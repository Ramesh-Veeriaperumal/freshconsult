if Rails.env.test?
  FactoryGirl.define do
    factory :va_rule, :class =>VaRule do
      name "Test Rule"
      description "Testing"
      match_type "all"
      active true
      action_data [{:name=> "priority", :value=>"3"}, {:name=> "status", :value=> "3"}]
    end
    
    factory :scn_automation, :class =>ScenarioAutomation do |v|
      name "Test Rule"
      description "Testing"
      match_type "all"
      active true
      action_data [{:name=> "priority", :value=>"3"}, {:name=> "status", :value=> "3"}]
    end
  end
end

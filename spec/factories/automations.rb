if Rails.env.test?
  Factory.define :va_rule, :class =>VARule do |v|
    v.name "Test Rule"
    v.description "Testing"
    v.match_type "all"
    v.active true
    v.action_data [{:name=> "priority", :value=>"3"}, {:name=> "status", :value=> "3"}]
  end

   Factory.define :scn_automation, :class =>ScenarioAutomation do |v|
    v.name "Test Rule"
    v.description "Testing"
    v.match_type "all"
    v.active true
    v.action_data [{:name=> "priority", :value=>"3"}, {:name=> "status", :value=> "3"}]
  end
end

module DispatcherTests

	def test_dispatcher_create_when_action_data_present 
         initial_va_rules_count = @account.va_rules.count
         action = [{:name => "priority" , :value => "2"}].to_json
         post :create , {:va_rule => {:name => "test_dispatcher"} , :action_data => action }
         current_va_rules_count = @account.va_rules.count
         assert_equal current_va_rules_count -1 , initial_va_rules_count
	end
end
module DispatcherNegativeTests

	def test_dispatcher_create_when_action_data_not_present
		 initial_va_rules_count = @account.va_rules.count
         post :create , {:va_rule => {:name => "test_dispatcher"}, :action_data => ""}
         current_va_rules_count = @account.va_rules.count
         assert_equal current_va_rules_count , initial_va_rules_count
	end
end

class VA::Tester::Performer < VA::Tester  

  def perform ticket, option_name, performer_data, op_types
    test_cases = performer_data.delete(:result)
    va_rule = create_va_rule(performer_data)
    test_cases.each do |performer, expected_result|
      returned = execute_va_rule va_rule, performer, ticket
      check_working returned, expected_result, va_rule, performer
      print_progress_dot
    end
  end

  def create_va_rule performer_data
    filter_data = DEFAULT_FILTER_DATA.merge(:performer => performer_data)
    scoper.create(
      :name => "Test VARule #{performer_data.object_id}", 
      :description => Faker::Lorem.sentence(100),
      :match_type  => 'any',
      :filter_data => filter_data,
      :action_data => DEFAULT_ACTION_DATA,
      :active => true
    )
  end

  def execute_va_rule va_rule, performer, ticket
    va_rule.performer.matches? performer, ticket
  end

  def check_working returned, expected_result, va_rule, performer
    unless returned == expected_result
      raise "Performer Mismatch : Expected #{expected_result}, Returned #{returned} : For performer #{performer.inspect} and va_rule #{va_rule.inspect}"
    end
  end

  def scoper
    Account.current.observer_rules
  end

end
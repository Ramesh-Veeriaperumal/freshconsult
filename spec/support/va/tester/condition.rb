class VA::Tester::Condition < VA::Tester

  attr_accessor :op_types

  def perform ticket, option_name, option_hash, op_types
    p "Testing option #{option_name}"
    @op_types = op_types
    operator_type = test_variable[option_name]['operatortype']
    op_types[operator_type].each do |operator|
      va_rule = create_va_rule(rule_data(option_name, option_hash[:feed_data], operator))
      execute_va_rule va_rule, ticket
      check_working va_rule, ticket, option_name, option_hash, operator, operator_type
    end
  end

end
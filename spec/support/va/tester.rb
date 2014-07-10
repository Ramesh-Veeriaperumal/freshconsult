class VA::Tester

  DEFAULT_FILTER_DATA = { 
    :events     =>  [{ :name => 'reply_sent' }],
    :performer  =>  { :type => "2" },
    :conditions =>  [{ :value => "2",
                      :operator => 'is_not',
                      :name => 'status' }]
  }
  DEFAULT_ACTION_DATA = [{
    :name  => :priority,
    :value => '3'
  }]

  attr_accessor :test_variable

  def initialize test_variable
    @test_variable = test_variable
  end

  def fetch_random_unique_choice option
    sub_rule = test_variable[option]
    random_choice = sub_rule['choices'].reject{|choice| choice[0]=='' }.sample
    random_choice_value = random_choice[0]
  end

  def perform ticket, option_name, option_hash, op_types = nil
    va_rule = create_va_rule(rule_data(option_name, option_hash[:feed_data]))
    execute_va_rule va_rule, ticket
    check_working va_rule, ticket, option_name, option_hash
    print_progress_dot
  end

  def create_va_rule data
    scoper.create(
      :name => "Test VARule #{data.object_id}", 
      :description => Faker::Lorem.sentence(100),
      :match_type  => 'any',
      :filter_data => data[:filter_data] || DEFAULT_FILTER_DATA,
      :action_data => data[:action_data] || DEFAULT_ACTION_DATA,
      :active => true
    )
  end

  def execute_va_rule va_rule, ticket
    # Intentionally Not doing anything
  end

  def exception? option_hash
    option_hash[:exception] == true
  end

  def print_progress_dot
    print "\e[32m.\e[0m"
  end

end
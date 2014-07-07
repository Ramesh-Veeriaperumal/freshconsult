class Wf::TestCase
  # created_at filter test cases are in tickets_controller_spec

  include AccountHelper
  include UsersHelper
  include Wf::FilterHelper
  include Wf::TestCaseGenerator
  include Wf::OperatorHelper
  include Wf::OptionSelecter

  PARAMS = { :wf_model => "Helpdesk::Ticket", :wf_order => "created_at", :wf_per_page => 100000,
    :wf_order_type => "desc", :visibility => { "visibility" => "3", "user_id" => "1", "group_id" => "1" } }

  def initialize filters
    @filters = filters
  end

  def working
    before_all
    prep_ticket
    define_test_cases
    success = []
    @filter_test_cases.each do |test_case|
      name = test_case[:name]
      params = PARAMS.merge(:data_hash => [test_case].to_json)
      tickets = @account.tickets.filter(:filter => 'Helpdesk::Filters::CustomTicketFilter', 
                                        :params => params)

      should_filter = verify_filtered test_case
      filtered = (tickets.include?(@ticket))
      raise "Mismatch while filtering ticket #{@ticket} based on #{name} 
            with the filter params #{params}" unless should_filter == filtered
      print_progress_dot
    end
  end

  private

    def verify_filtered test_case
      operator = test_case[:operator]
      name = test_case[:name]
      value = test_case[:value]
      send(operator, name, value)
    end

    def print_progress_dot
      print "\e[32m.\e[0m"
    end
end

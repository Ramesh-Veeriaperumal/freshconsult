module VA::RuleHelper

  PERFORMER = :dummy_constant
  TESTS = { Helpdesk::ScenarioAutomationsController     => { :tester_class => VA::Tester::Action,                :test_cases => [VA::RandomCase::Action],                :test_variable => :action_defs },
            Admin::VaRulesController         => { :tester_class => VA::Tester::Condition::Dispatcher, :test_cases => [VA::RandomCase::Condition::Dispatcher], :test_variable => :filter_defs },
            Admin::SupervisorRulesController => { :tester_class => VA::Tester::Condition::Supervisor, :test_cases => [VA::RandomCase::Condition::Supervisor], :test_variable => :filter_defs },
            Admin::ObserverRulesController   => { :tester_class => VA::Tester::Event,                 :test_cases => [VA::RandomCase::Event],                 :test_variable => :event_defs },
            PERFORMER                        => { :tester_class => VA::Tester::Performer,             :test_cases => [VA::RandomCase::Performer],             :test_variable => :event_defs }
          } # Order determines the method definition as they are overridden by these modules

  FETCH_FROM_CONTROLLERS = [Helpdesk::ScenarioAutomationsController, Admin::VaRulesController, Admin::SupervisorRulesController, Admin::ObserverRulesController]
  FETCH_VARIABLES = [:action_defs, :filter_defs, :event_defs, :time_based_filters, :op_types]

  def before_each
    @account = create_test_account
    @account.features.multi_product.create
    @agent2 = add_test_agent(@account)
    @agent2.make_current
    @agent3 = add_test_agent(@account)
    @product = @account.products.create(Factory.attributes_for(:product)) # to make it multi product
    @to_email = @account.email_configs.first.to_email
    @ticlet_cc = Faker::Internet.email
    define_required_accessors
    build_all_possible_options
  end

  def create_required_objects
    @product = @account.products.create(Factory.attributes_for(:product))
    @company = @account.companies.create(Factory.attributes_for(:company))
    @requester = @account.users.create(Factory.attributes_for(:user, :email => Faker::Internet.email, :customer_id => @company.id))
    @responder = add_test_agent(@account)
    @ticket = @account.tickets.create(Factory.attributes_for(:ticket, :requester_id => @requester.id, :responder_id => @responder.id))
    @agent_note =@ticket.notes.create(Factory.attributes_for(:helpdesk_note, :notable_id => @ticket.id, :user_id => User.current.id, :source => 2))
    @user_note = @ticket.notes.create(Factory.attributes_for(:helpdesk_note, :notable_id => @ticket.id, :user_id => @requester.id))
    @time_sheet = @ticket.time_sheets.create
    @survey_result = @ticket.survey_results.create(:rating => 1)
    ###Need to define custom fields
    @ticket.to_email = @to_email
    @ticket.cc_email[:cc_emails] << @ticlet_cc
    @ticket.ticket_states.pending_since = Time.now+3600
    @ticket.ticket_states.resolved_at = Time.now+3600
    @ticket.ticket_states.closed_at = Time.now+3600
    @ticket.ticket_states.opened_at = Time.now+3600
    @ticket.ticket_states.assigned_at = Time.now+3600
    @ticket.ticket_states.requester_responded_at = Time.now+3600
    @ticket.ticket_states.first_assigned_at = Time.now+3600
    @ticket.ticket_states.agent_responded_at = Time.now+3600
    @ticket.frDueBy = Time.now+3600
    @ticket.due_by = Time.now+3600
    @ticket.ticket_states.save
  end

  def clear_background_jobs
    clear_delayed_jobs
    clear_resque
  end

  private

    def define_required_accessors
      FETCH_VARIABLES.each do |variable|
        self.class.send(:attr_accessor, variable)
        send :"#{variable}=", {}
      end
    end

    def build_all_possible_options
      FETCH_FROM_CONTROLLERS.each do |controller| # Looping through all controllers to consolidate all the options
        @helper = ControllerDataFetcher.new(controller)
        @helper.fetch_data
        ControllerDataFetcher::RETRIEVE_VARIABLES[controller].each do |variable|
          send(variable).merge!(remove_dummy_options(@helper.send(variable), controller))
        end
      end
    end

    def remove_dummy_options variable_json, controller # using the same for op_types, though doesn't make sense
      variable_json = variable_json.to_json if variable_json.is_a?(Array) # For Time Based Filters
      variable = ActiveSupport::JSON.decode(variable_json).reject{ |option| 
        option['name']==-1 || (option['name']=='created_at' && controller == Admin::SupervisorRulesController) }
      return variable if variable.is_a?(Hash)
      Hash[variable.each.map do |option| [option['name'].to_sym, option] end] #Hash to do an easy unique merge
    end

    def clear_delayed_jobs
      Delayed::Job.delete_all
    end

    def clear_resque
      queues = Resque.queues
      queues.each do |queue_name|
        Resque.redis.del "queue:#{queue_name}"
      end
    end

end
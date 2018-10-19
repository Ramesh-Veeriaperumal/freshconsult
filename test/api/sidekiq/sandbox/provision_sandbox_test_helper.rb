require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze
['ticket_template_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
Dir["#{Rails.root}/test/core/helpers/*.rb"].each { |file| require file }
Dir.glob("#{Rails.root}/test/api/sidekiq/sandbox/*_sandbox_helper.rb") { |file| require file }

module ProvisionSandboxTestHelper
  include GroupHelper
  include ::TicketFieldsTestHelper
  include TicketTemplateHelper
  include TicketsTestHelper
  include TicketFieldsSandboxHelper
  include TicketTemplatesSandboxHelper
  include TagsSandboxHelper
  include RolesSandboxHelper
  include SlaPoliciesSandboxHelper
  include EmailNotificationsSandboxHelper
  include CompanyFormSandboxHelper
  include ContactFormSandboxHelper
  include CustomSurveysSandboxHelper
  include StatusGroupsSandboxHelper
  include GroupsSandboxHelper
  include SkillsSandboxHelper
  include VaRulesSandboxHelper
  include PasswordPolicesSandboxHelper
  include AgentsSandboxHelper
  include CannedResponsesSandboxHelper

  IGNORE_TABLES = ["helpdesk_shared_attachments", "helpdesk_attachments", "users", "agents", "user_emails", "helpdesk_tags", "helpdesk_accesses"]
  MODELS = ['canned_responses', 'agents', 'ticket_fields', 'skills', 'password_policies', 'va_rules', 'sla_policies', 'email_notifications', 'company_form', 'contact_form', 'custom_surveys', 'status_groups', 'roles', 'tags']
  MODEL_TABLE_MAPPING = Hash[ActiveRecord::Base.send(:descendants).collect {|c| [c.name, c.table_name]}]
  def model_table_mapping
    @model_table_mapping = Hash[ActiveRecord::Base.send(:descendants).collect {|c| [c.name, c.table_name]}]
  end

  def table_model_mapping
    @table_model_mapping = Hash[MODEL_DEPENDENCIES.keys.collect {|table| [model_table_mapping[table], table]}]
  end

  def sandbox_affected_tables
    @sandbox_affected_tables ||= MODEL_DEPENDENCIES.keys.map {|table| model_table_mapping[table]}.compact - IGNORE_TABLES
  end

  def account_list_data(account_id)
    shard_name = ShardMapping.find_by_account_id(account_id).try(:[], :shard_name)
    account_data = {}
    Sharding.run_on_shard(shard_name) do
      sandbox_affected_tables.each do |table|
        account_data[table] = column_exists?(table, 'id') ? sql_list_query(account_id, table) : [sql_count_query(account_id, table)]
      end
    end
    account_data
  end

  def column_exists?(table, column_name)
    table_model_mapping[table].constantize.columns.map(&:name).include?(column_name)
  end

  def models_data(master_account_id, sandbox_account_id)
    master_account_data = account_list_data(master_account_id)
    sandbox_account_data = account_list_data(sandbox_account_id)
    {:master_account_data => master_account_data, :sandbox_account_data => sandbox_account_data}
  end

  def match_data(master_account_id, sandbox_account_id)
    master_account_data = account_list_data(master_account_id)
    sandbox_account_data = account_list_data(sandbox_account_id)
    Rails.logger.info " Master account data #{master_account_data.inspect} Sandbox account data#{sandbox_account_data.inspect}"
    master_account_data.each do |table, ids|
      assert_equal ids.sort, sandbox_account_data[table].sort
    end
  end

  def sql_list_query(account_id, table_name)
    sql = "select id from #{table_name} where account_id = #{account_id}"
    sql += " and deleted = 0" if column_exists?(table_name, 'deleted')
    ActiveRecord::Base.connection.execute(sql).collect {|record| record[0]}
  end

  def sql_count_query(account_id, table_name)
    sql = "select count(*) from #{table_name} where account_id = #{account_id}"
    ActiveRecord::Base.connection.execute(sql).first.try(:[], 0).to_i
  end

  def create_sandbox(account, user)
    Sharding.run_on_shard('shard_1') do
      Account.reset_current_account
      User.reset_current_user
      Admin::Sandbox::CreateAccountWorker.new.perform({ :account_id => account.id, :user_id => user.id })
      account.reload
      @account = account.make_current
      user.make_current
      job = account.sandbox_job
      create_sample_data_production(@account)
      Admin::Sandbox::DataToFileWorker.new.perform({})
      Admin::Sandbox::FileToDataWorker.new.perform
      create_conflicts_in_production(@account)
    end
  end

  def create_ticket_templates(account)
    enable_adv_ticketing(:parent_child_tickets) do
      @groups = []
      @agent = get_admin
      3.times { @groups << create_group(account) }
      10.times do
        create_tkt_template(name: Faker::Name.name,
                            association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general],
                            account_id: @account.id,
                            accessible_attributes: {
                                access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                            })
      end
    end
  end

  def create_ticket_fields(account)
    account.ticket_fields.custom_fields.each(&:destroy)
    create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    CUSTOM_FIELDS.each do |custom_field|
      next if %w(dropdown country state city).include?(custom_field)
      create_custom_field("test_custom_#{custom_field}", custom_field)
    end
    create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
  end

  def create_sample_data_production(account)
    MODELS.each do |model|
      next if model == "ticket_fields"
      send("create_#{model}_data", account) if respond_to?("create_#{model}_data")
      send("create_#{model}_data_for_conflict", account) if respond_to?("create_#{model}_data_for_conflict")
    end
  end

  def create_conflicts_in_production(account)
    MODELS.each do |model|
      send("create_conflict_#{model}_in_production", account) if respond_to?("create_conflict_#{model}_in_production")
    end
  end

  def create_sample_data_sandbox(sandbox_account_id)
    diff = {}
    MODELS.each do |model|
      diff[model] ||= []
        Sharding.run_on_shard('sandbox_shard_1') do
          @account = Account.find(sandbox_account_id).make_current
          diff[model] = send("#{model}_data", @account)
        end
    end
    diff
  end

  def delete_sandbox_references(account)
    sandbox_job = account.sandbox_job
    sandbox_job.destroy if sandbox_job
  end

  def sandbox_account_exists(sandbox_account_id)
    assert_equal ShardMapping.find_by_account_id(sandbox_account_id), nil
  end

  def update_data_for_delete_sandbox(sandbox_account_id)
    update_sandbox_account_currency(sandbox_account_id)
    Integrations::Application.stubs(:find_by_name).with('jira').returns(Integrations::Application.new)
  end

  def delete_sandbox_data
    return unless @sandbox_account_id
    update_data_for_delete_sandbox(@sandbox_account_id)
    @production_account.make_current
    Admin::Sandbox::DeleteWorker.new.perform
    return unless ShardMapping.find_by_account_id(@sandbox_account_id)
    Sharding.admin_select_shard_of(@sandbox_account_id) do
      MODEL_DEPENDENCIES.keys.map {|table| model_table_mapping[table]}.compact.each do |table|
        sql = "DELETE from #{table} where account_id = #{@sandbox_account_id}"
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end


  def update_sandbox_account_currency(sandbox_account_id)
    Sharding.admin_select_shard_of(sandbox_account_id) do
      sandbox_account = Account.find(sandbox_account_id)
      currency = Subscription::Currency.find_by_name("USD")
      if currency.blank?
        currency = Subscription::Currency.create({ :name => "USD", :billing_site => "freshpo-test",
                                                   :billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e", :exchange_rate => 1})
      end
      subscription = sandbox_account.subscription
      subscription.set_billing_params("USD")
      subscription.state.downcase!
      subscription.sneaky_save
    end
  end
end

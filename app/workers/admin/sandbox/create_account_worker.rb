class Admin::Sandbox::CreateAccountWorker < BaseWorker
  sidekiq_options queue: :create_sandbox_account, retry: 0, backtrace: true, failures: :exhausted

  include AccountConstants

  RANDOM_NUMBER_RANGE = 10**5
  BASE_DOMAIN         = AppConfig['base_domain'][Rails.env]

  def perform(args)
    args.symbolize_keys!
    Sharding.select_shard_of(args[:account_id]) do
      @account = Account.find(args[:account_id])
      @user    = @account.users.find(args[:user_id])
      @job     = @account.sandbox_job
      create_sandbox_account if @job.sandbox_account_id.nil?
    end
  end

  private

  def create_sandbox_account
    @job.mark_as!(:create_sandbox)
    signup = signup_account
    # Setting make current again for master account and user because it will update during creating new account
    @account.make_current
    @user.make_current
    @job.sandbox_account_id = signup.account_id
    @job.mark_as!(:account_complete)
    set_production_url
    # Sync Config changes from production to sandbox
    ::Admin::Sandbox::ConfigToFileWorker.perform_async({})
  rescue => e
    Rails.logger.error "Error in creating sandbox account #{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e,"Sandbox signup error")
    @job.update_last_error(e) if @job
  end

  def set_production_url
    Sharding.select_shard_of @job.sandbox_account_id do
      sandbox_account = Account.find(@job.sandbox_account_id)
      (sandbox_account.account_additional_settings.additional_settings[:sandbox] ||= {}).merge!(:production_url=>@account.full_domain)
      sandbox_account.account_additional_settings.save
    end
  end

  def signup_account
    params = {
        account_name: 'Sandbox-' + @account.name,
        account_domain: sandbox_url,
        locale: @account.language,
        user_name: @user.name,
        user_email: @user.email,
        user_helpdesk_agent: true,
        account_account_type: Account::ACCOUNT_TYPES[:sandbox],
        account_time_zone: @account.time_zone
    }
    current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
    Sharding.run_on_shard "sandbox_#{current_shard}" do
      signup = Signup.new(params)
      signup.save!
      signup
    end
  end

  def valid_domain?(domain)
    DomainGenerator.valid_domain?(domain)
  end

  def sandbox_url
    domain     = "#{@account.full_domain.split('.')[0]}sandbox"
    new_domain = domain + '.' + BASE_DOMAIN
    valid_domain?(new_domain) ? domain : random_domain(domain)
  end

  def random_domain(domain)
    5.times do
      current_domain_suggestion = "#{domain}#{SecureRandom.random_number(RANDOM_NUMBER_RANGE)}"
      return current_domain_suggestion if valid_domain?(current_domain_suggestion+ "." + BASE_DOMAIN)
    end
  end
end

class Admin::Sandbox::CreateAccountWorker < BaseWorker
  sidekiq_options queue: :create_sandbox_account, retry: 0,  failures: :exhausted

  include AccountConstants

  RANDOM_NUMBER_RANGE = 10**5
  BASE_DOMAIN         = AppConfig['base_domain'][Rails.env]
  FRESHID_FEATURES = %i[freshid freshid_org_v2].freeze
  FEATURE_TYPES       = %w[launch features_list].freeze

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
      @job.sandbox_account_id = signup.account_id
      post_account_creation_activites
      # Setting make current again for master account and user because it will update during creating new account
      set_trial_period(@job.sandbox_account_id)
      @account.make_current
      @user.make_current
      @job.mark_as!(:account_complete)
      # Sync Config changes from production to sandbox
      ::Admin::Sandbox::DataToFileWorker.perform_async({})
    rescue StandardError => e
      Rails.logger.error "Error in creating sandbox account :: Error: #{e.inspect} :: Backtrace: #{e.backtrace[0..50].inspect}"
      @job.update_last_error(e, :build_error) if @job
      NewRelic::Agent.notice_error(e, description: 'Sandbox signup error')
    ensure
      Thread.current[:create_sandbox_account] = nil
    end

    def post_account_creation_activites
      Sharding.select_shard_of @job.sandbox_account_id do
        sandbox_account = Account.find(@job.sandbox_account_id).make_current
        FEATURE_TYPES.each { |feature_type| rollback_sign_up_features(@account, sandbox_account, feature_type) }
        (sandbox_account.account_additional_settings.additional_settings[:sandbox] ||= {})[:production_url] = @account.full_domain
        sandbox_account.account_additional_settings.save
        sandbox_account.reputation = @account.verified? # Verify the sandbox account
        sandbox_account.save
      end
    ensure
      Account.reset_current_account
    end

    def rollback_sign_up_features(main_account, sandbox_account, feature_type)
      main_account_features = main_account.safe_send(feature_type)
      sandbox_account_features = sandbox_account.safe_send(feature_type)
      features_to_rollback = sandbox_account_features - main_account_features
      action = feature_type == 'launch' ? 'rollback' : 'revoke_feature'
      sandbox_account.destroy_freshid_account if (features_to_rollback & FRESHID_FEATURES).present?
      features_to_rollback.each { |feature| sandbox_account.safe_send(action, feature) }
    end

    def signup_account
      params = {
        account_name: 'Sandbox-' + @account.name,
        account_domain: sandbox_url,
        locale: @account.language,
        user_name: @user.name.tr('^a-zA-Z0-9', ' '),
        user_email: @user.email,
        user_helpdesk_agent: true,
        account_account_type: Account::ACCOUNT_TYPES[:sandbox],
        time_zone: @account.time_zone,
        direct_signup: true
      }
      params.merge!(freshid_v2_signup_params) if @account.freshid_org_v2_enabled?
      Thread.current[:create_sandbox_account] = true
      Sharding.run_on_shard(SANDBOX_SHARD_CONFIG) do
        signup = Signup.new(params)
        signup.save!
        signup
      end
    end

    def set_trial_period(sandbox_account_id)
      Sharding.select_shard_of sandbox_account_id do
        sandbox_account = Account.find(sandbox_account_id).make_current
        subscription = sandbox_account.subscription
        data = { trial_end: AccountConstants::SANDBOX_TRAIL_PERIOD.days.from_now.utc.to_i }
        result = Billing::ChargebeeWrapper.new.update_subscription(subscription.account_id, data)
        raise unless result.subscription.status.eql?('in_trial')
        subscription.update_column(:next_renewal_at, Time.at(result.subscription.trial_end).utc)
        subscription.update_column(:state, subscription.state.downcase)
      end
    rescue StandardError => e
      Rails.logger.error "Error in extending sandbox trial period #{e.message} #{e.backtrace[0..10].inspect}"
      NewRelic::Agent.notice_error(e, description: 'Sandbox trial extension error')
    ensure
      Account.reset_current_account
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
        return current_domain_suggestion if valid_domain?(current_domain_suggestion + '.' + BASE_DOMAIN)
      end
    end

    def freshid_v2_signup_params
      @account.make_current
      @user.make_current
      join_token = Freshid::V2::Models::Organisation.join_token
      {
        join_token: join_token,
        fresh_id_version: Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2,
        org_domain: @account.organisation_domain
      }
    rescue Exception => e
      Rails.logger.error("FRESHID exception in Admin::Sandbox::CreateAccountWorker, freshid_account_params: #{e.message}, #{e.backtrace}")
      freshid_params = {}
    ensure
      User.reset_current_user
      Account.reset_current_account
    end

end

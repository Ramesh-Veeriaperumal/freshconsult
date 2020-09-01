class Channel::Freshcaller::MigrationController < ApiApplicationController
  
  include ::Freshcaller::JwtAuthentication
  include TwilioMaster
  
  skip_before_filter :check_privilege, :check_day_pass_usage_with_user_time_zone, :load_object
  before_filter :custom_authenticate_request
  around_filter :run_on_all_shardings, only: :fetch_pod_info
  around_filter :select_slave_shard, only: [:validate, :cross_verify]
  around_filter :select_master_shard, only: [:initiate, :revert, :reset_freshfone]
  before_filter :load_account, only: [:validate, :initiate, :cross_verify, :revert, :reset_freshfone]
  
  def validate
    @errors = []
    @errors << "Freshdesk account not active" unless (@account.subscription.active? || (@account.subscription.sprout? && @account.subscription.free?))
    @errors << "Freshfone Account not active" unless freshfone_account_active?
    @errors << "Twilio Account not active" unless (twilio_subaccount.status == 'active')
    @errors << "No Freshfone numbers" unless (@account.freshfone_numbers.present?)
    @errors << "Freshcaller account present" if @account.freshcaller_account
    @errors << "No common admin email" if common_account_admin.blank? && params[:admin_email].present?
    @errors << number_sid_mismatch_error unless number_mismatches.blank?
    @agent_limit = @account.subscription.agent_limit
  end

  def initiate
    @errors = []
    return @errors << "Live calls happening" if @account.freshfone_calls.active_calls.present?
    @account.features.freshfone.delete
    @account.add_feature(:falcon) if params[:toggle_mint] == 'true'
    @jid = Freshfone::FreshcallerMigrationWorker.perform_async(migration_params)
    Rails.logger.info "Migration worker JID:::::::::::#{@jid}"
  end

  def cross_verify
    @freshcaller_account_id = @account.freshcaller_account.freshcaller_account_id
    @errors = []
    @errors << "Numbers still not migrated" if @account.freshfone_numbers.present?
    @errors << "Credits not ported" unless @account.freshfone_credit.available_credit.zero?
    @errors << "Freshcaller feature not added" unless @account.has_feature?(:freshcaller)
    @errors << "Freshcaller widget feature not added" unless @account.has_feature?(:freshcaller_widget)
  end

  def fetch_pod_info
    domain_record = DomainMapping.find_by_account_id(params[:id])
    shard_details = ShardMapping.find_by_account_id(domain_record.account_id) if domain_record
    @result = shard_details ? shard_details.pod_info : ''
  end

  def revert
    @errors = []
    @account.revoke_feature(:freshcaller) if @account.has_feature?(:freshcaller)
    @account.revoke_feature(:freshcaller_widget) if @account.has_feature?(:freshcaller_widget)
    revert_account
    revert_users
    revert_numbers
    revert_credits(params[:credits])
  end

  def reset_freshfone
    @account.features.freshfone.create
  end

  def revert_users
    @account.agents.preload(:freshcaller_agent).each do |agent|
      next if agent.freshcaller_agent.blank?  
      agent.freshcaller_agent.destroy
      puts "Agent disabled :: #{agent.freshcaller_agent.inspect}"
    end
  end

  def revert_account
    @account.freshcaller_account.destroy if @account.freshcaller_account
    @account.freshfone_account.update_column(:state, Freshfone::Account::STATE_HASH[:active])
    @account.features.freshfone.create unless @account.features?(:freshfone)
    puts "Account restored :: #{@account.freshfone_account.inspect}"
  end

  def revert_numbers
    app_sid = twilio_subaccount.applications.get(@account.freshfone_account.twilio_application_id).sid
    @account.all_freshfone_numbers.each do |number|
      fnumber = twilio_subaccount.incoming_phone_numbers.get(number.number_sid)
      begin
        if fnumber.phone_number.present?
          fnumber.update(voice_application_sid: app_sid)
          number.update_column(:deleted, false)
          Rails.logger.info "Number restored :: #{number.inspect}"
          Rails.logger.info "app sid :: #{fnumber.voice_application_sid}"
        end
      rescue Twilio::REST::RequestError => error
        Rails.logger.info "Deleted Number \n#{error.message}\n#{error.backtrace.join("\n\t")}"
      end
    end
  end

  def revert_credits(credits)
    @account.freshfone_credit.update_attributes(available_credit: credits)
    puts "Credits :: #{@account.freshfone_credit.inspect}"
  end


  def select_slave_shard
    Rails.logger.debug "Selecting via SLAVE SHARD"
    Sharding.admin_select_shard_of(params[:id]) do
      Sharding.run_on_slave do
        yield
      end
    end
  end

  def select_master_shard
    Rails.logger.debug 'Selecting via MASTER SHARD'
    Sharding.admin_select_shard_of(params[:id]) do
      yield
    end
  end

  def run_on_all_shardings
    Sharding.run_on_all_shards do
      yield
    end
  end

  def load_account
    ::Account.reset_current_account
    @account = Account.find(params[:id])
    @account.make_current
  end

  def common_account_admin
    roles ||= @account.roles.where(name: 'Account Administrator').first
    users ||= @account.users.where(privileges: roles.privileges, email: params[:admin_email]).reorder('id asc')
    user ||= users.first
  end

  def freshfone_account_active?
    @account.freshfone_account && [Freshfone::Account::STATE_HASH[:active], Freshfone::Account::STATE_HASH[:trial]].include?(@account.freshfone_account.state)
  end

  def number_mismatches
    @number_mismatches ||= fetch_number_sid_mismatches
  end

  def fetch_number_sid_mismatches
    number_sid_mismatches = []
    twilio_subaccount.incoming_phone_numbers.list.each do |number|
      Rails.logger.info "Number Sid:::::::::::#{number.sid}"
      numbers = @account.freshfone_numbers.where(number_sid: number.sid)
      number_sid_mismatches << number.sid if numbers.blank?
    end
    number_sid_mismatches
  end

  def twilio_subaccount
    @twilio_subaccount ||= @account.freshfone_account.twilio_subaccount
  end

  def number_sid_mismatch_error
    number_mismatch_error_string = "Number sid mismatching for number sids"
    number_mismatches.each do |number_sid| 
      number_mismatch_error_string << ", #{number_sid}"
    end
    number_mismatch_error_string
  end

  def migration_params
    params[:account_creation] ? new_migration_params : existing_account_migration_params
  end

  def new_migration_params
    { account_id: params[:id],
      email: params[:sender_email],
      account_creation: params[:account_creation]
    }
  end

  def existing_account_migration_params
    new_migration_params.merge(  
    { freshcaller_account_id: params[:freshcaller_account_id],
      freshcaller_account_domain: params[:freshcaller_domain],
      fc_user_id: params[:freshcaller_user_id],
      fc_user_email: params[:freshcaller_user_email],
      plan_name: plan_name
    })
  end

  def plan_name
    return 'Advance' if @account.subscription.addons.where(name: "Call Center Advanced").present?
    'Standard'
  end

end

class Freshid::Fdadmin::FreshidValidateAndFix
  include Freshid::Fdadmin::MigrationHelper

  FRESHID_VALIDATION_TIMEOUT_DELAY = 300 # 5 Mins

  def initialize(doer_email, freshid_type = :freshid)
    @doer_email = doer_email
    @account = ::Account.current
    @freshid_type = freshid_type
    @diff_count = 0
    @error_count = 0
    @same_count = 0
    @validation_log = []
    @validation_log << ['AgentID', 'Agent Email', 'Auth_uid', 'Freshid_uid', 'Sucess', 'Error']
  end

  def freshops_account_validation(account_id)
    Sharding.admin_select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      if safe_send(:"check_and_enable_#{@freshid_type.to_s}", @account)
        account_validation
      else
        Rails.logger.debug "Freshid Validation :: freshops_account_validation :: FreshID Not Enabled for a=#{@account.id}"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Freshid Validation Error :: freshops_account_validation a=#{account_id} :: error message=#{e.message}"
  ensure
    Account.reset_current_account
  end

  def account_validation
    Rails.logger.info "Freshid Validation :: Started validation for a=#{@account.id}"
    validation_timeout_redis_key = format(FRESHID_VALIDATION_TIMEOUT, account_id: @account.id.to_s)
    set_others_redis_key(validation_timeout_redis_key, true, FRESHID_VALIDATION_TIMEOUT_DELAY)
    @account.all_technicians.find_each do |user|
      next if user.email == CUSTSERV_EMAIL

      @user = user
      agent_validation
    end
    Rails.logger.info "Freshid Validation :: account_validation :: Finished validation for a=#{@account.id}"
  rescue StandardError => e
    Rails.logger.error "Freshid Validation Error :: account_validation :: a=#{@account.id}, error message=#{e.message}"
  ensure
    subject = "#{FRESHID_VALIDATION_EMAIL_SUBJECT} A = #{@account.id}"
    message = "#{@freshid_type} Validation Logs attached Valid. Agent Count = #{@same_count} :: Updated Agent count = #{@diff_count} :: Erred Agent Count = #{@error_count}. Apply the suitable filter in SUCCESS column to see the erred agents."
    write_file('validation_logs.csv', @validation_log.map(&:to_csv).join)
    file_list = ['validation_logs.csv']
    Emailer.export_logs(file_list, subject, message, @doer_email)
    delete_file('validation_logs.csv')
  end

  def freshops_agent_validation(account_id, user_email)
    Sharding.admin_select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      @user = @account.users.find_by_email(user_email).make_current
      agent_validation
    end
  rescue StandardError => e
    Rails.logger.error "Freshid Validation Error :: freshops_agent_validation  a=#{account_id}, user=#{user_email} :: error message=#{e.message}"
  ensure
    Account.reset_current_account
  end

  private

  def agent_validation
    Rails.logger.info "Freshid Validation :: Started validation for a=#{@account.id}, user_id=#{@user.id}"

    freshid_user_class = @freshid_type == :freshid_v2 ? Freshid::V2::Models::User : Freshid::User
    freshid_user = freshid_user_class.find_by_email(@user.email)
    authorization = @user.freshid_authorization

    freshid_user_id = @freshid_type == :freshid_v2 ? freshid_user.try(:id) : freshid_user.try(:uuid)
    if authorization.present? && freshid_user_id
      # uid mismatch
      if freshid_user_id != authorization.uid
        authorization.uid = freshid_user_id
        authorization.save!
        @diff_count += 1
      else
        @same_count += 1
      end
      @validation_log << [@user.id, @user.email, authorization.uid, freshid_user_id, true, '']
    elsif authorization.present? && freshid_user_id.blank?
      # freshid user not present
      freshid_user = @user.create_freshid_user
      if freshid_user.present? && freshid_user_id.present?
        authorization.uid = freshid_user_id
        authorization.save!
        @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user_id, true, '']
        @diff_count += 1
      else
        @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user_id, false, freshid_user.inspect]
        @error_count += 1
      end
    elsif authorization.blank? && freshid_user_id
      # authorization not present
      @user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: freshid_user_id)
      @user.save!
      @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user_id, true, '']
      @diff_count += 1
    else
      Rails.logger.debug "Freshid Validation Error :: a=#{@account.id}, user_email=#{@user.email}, user_id=#{@user.id}"
      @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user_id, false, 'unknown error']
      @error_count += 1
    end
    Rails.logger.info "Freshid Validation :: Finished validation for a=#{@account.id}, user_id=#{@user.id}"
  rescue StandardError => e
    @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user_id, false, e.message]
    Rails.logger.error "Freshid Validation Error :: agent_validation :: a=#{@account.id}, user_email=#{@user.email}, user_id=#{@user.id} :: error message=#{e.message}"
    @error_count += 1
  end
end

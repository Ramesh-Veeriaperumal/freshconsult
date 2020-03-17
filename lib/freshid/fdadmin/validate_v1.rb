class Freshid::Fdadmin::ValidateV1
  include Freshid::Fdadmin::MigrationHelper
  def initialize(doer_email)
    @doer_email = doer_email
    @account = ::Account.current
    @diff_count = 0
    @error_count = 0
    @same_count = 0
    @validation_log = []
    @validation_log << ['AgentID', 'Agent Email', 'Auth_uid', 'Freshid_uid', 'Sucess', 'Error']
  end

  def freshops_account_validation(account_id)
    Sharding.admin_select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      if check_and_enable_freshid(@account)
        account_validation
      else
        Rails.logger.debug "Freshid Validation :: freshops_account_validation :: FreshID Not Enabled for a=#{@account.id}"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Freshid Validation Error :: freshops_account_validation  a = #{account_id}:: error message #{e.message}"
  ensure
    Account.reset_current_account
  end

  def account_validation
    Rails.logger.info "Freshid Validation :: Started validation for a=#{@account.id}"
    @account.all_technicians.find_each do |user|
      next if user.email == CUSTSERV_EMAIL

      @user = user
      agent_validation
    end
    check_and_enable_freshid(@account)
    Rails.logger.info "Freshid Validation :: account_validation :: Finished validation for a=#{@account.id}"
  rescue StandardError => e
    Rails.logger.error "Freshid Validation Error :: account_validation :: error message #{e.message}"
  ensure
    subject = "#{FRESHID_VALIDATION_EMAIL_SUBJECT} A = #{@account.id}"
    message = "Freshid Validation Logs attached Valid. Agent Count = #{@same_count} :: Updated Agent count = #{@diff_count} :: Erred Agent Count = #{@error_count}. Apply the suitable filter in SUCCESS column to see the erred agents."
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
    Rails.logger.error "Freshid Validation Error :: freshops_agent_validation  a = #{account_id} user = #{user_email} :: error message #{e.message}"
  ensure
    Account.reset_current_account
  end

  def agent_validation
    Rails.logger.info "Freshid Validation :: Started validation for a=#{@account.id} and user_id=#{@user.id}"
    freshid_user = Freshid::User.find_by_email(@user.email)
    authorization = @user.freshid_authorization
    if authorization.present? && freshid_user.try(:uuid)
      # uid mismatch
      if freshid_user.uuid != authorization.uid
        authorization.uid = freshid_user.uuid
        authorization.save!
        @validation_log << [@user.id, @user.email, authorization.uid, freshid_user.try(:uuid), true, '']
        @diff_count += 1
      else
        @same_count += 1
      end
    elsif authorization.present? && freshid_user.try(:uuid).blank?
      # freshid user not present
      freshid_user = @user.create_freshid_user
      if freshid_user.present? && freshid_user.try(:uuid).present?
        authorization.uid = freshid_user.uuid
        authorization.save!
        @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user.try(:uuid), true, '']
        @diff_count += 1
      else
        @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user.try(:uuid), false, freshid_user.inspect]
        @error_count += 1
      end
    elsif authorization.blank? && freshid_user.try(:uuid)
      # authorization not present
      @user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: freshid_user.try(:uuid))
      @user.save!
      @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user.try(:uuid), true, '']
      @diff_count += 1
    else
      Rails.logger.debug "Freshid Validation Error ::  user = #{@user.email}, user_id = #{@user.id}"
      @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user.try(:uuid), false, 'unknown error']
      @error_count += 1
    end
    Rails.logger.info "Freshid Validation :: Finished validation for a=#{@account.id} and user_id=#{@user.id}"
  rescue StandardError => e
    @validation_log << [@user.id, @user.email, authorization.try(:uid), freshid_user.try(:uuid), false, e.message]
    Rails.logger.error "Freshid Validation Error :: agent_validation :: user = #{@user.email},  user_id = #{@user.id} :: error message #{e.message}, #{e.backtrace}"
    @error_count += 1
  end
end

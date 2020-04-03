class Roles::UpdateUserPrivileges < BaseWorker
  include Authority::FreshdeskRails::ModelHelpers

  sidekiq_options queue: :update_user_privilege, retry: 2, failures: :exhausted

  sidekiq_retries_exhausted do |msg|
    Rails.logger.error "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
    NewRelic::Agent.notice_error(msg)
  end

  def perform(args)
    @account = Account.current
    params = args.symbolize_keys

    role = @account.roles.find_by_id(params[:role_id])
    raise "Role is not present so no user updates for role_id:#{params[:role_id]} - action:#{params[:action]}" if role.blank?

    performed_by_user = @account.users.find_by_id(params[:performed_by_id]) if params[:performed_by_id]
    raise "performed by user is not present" if performed_by_user.nil?
    performed_by_user.make_current

    update_user_privileges(role)
    Rails.logger.info "Successfully updated users for acc:#{@account.id} - role_id:#{params[:role_id]}"
  rescue StandardError => e
    Rails.logger.error "Exception in UpdateUserPrivileges : account_id - #{@account.try(:id)} : args - #{args} : message - #{e.message} backtrace - #{e.backtrace}"
    NewRelic::Agent.notice_error(e)
  end

  private

    def update_user_privileges(role)
      role.users.find_each(batch_size: 300) do |user|
        privileges = (union_privileges user.roles).to_s
        user.update_attribute(:privileges, privileges)
      end
    end
end

class Roles::UpdateAgentsRoles < BaseWorker
  sidekiq_options :queue => :update_agents_roles, :retry => 0, :failures => :exhausted

  def perform(params)
    @account = Account.current
    params = params.symbolize_keys
    # To avoid account_admin's user_id inject.
    account_admin = @account.technicians.find_by_email(@account.admin_email)
    params_add_user_ids = params[:add_user_ids].split(',') if params[:add_user_ids]
    params_delete_user_ids = params[:delete_user_ids].split(',') if params[:delete_user_ids]
    add_user_ids = (params_add_user_ids || []) - [account_admin.try(:id).to_s]
    delete_user_ids = (params_delete_user_ids || []) - [account_admin.try(:id).to_s]

    update_role_ids(params[:role_id], add_user_ids, true) if add_user_ids.present?
    update_role_ids(params[:role_id], delete_user_ids) if delete_user_ids.present?
  end

  # If add is true then list of agent ids will be added with the role_id
  def update_role_ids role_id, list, add = false
    (@account.technicians.where(:id => list)).find_each do |user|
      new_role_ids = add ? user.role_ids.push(role_id) : user.role_ids - [role_id]
      user.update_attributes({"role_ids" => new_role_ids })
    end
  end
end
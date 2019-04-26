class Testing::FreshidApiController < ApiApplicationController

  #Organisation APIs

  def find_organisation_by_id
    org_id = params[:org_id]
    @data = Freshid::V2::Models::Organisation.find_by_id(org_id)
  end

  def find_organisation_by_domain
    org_domain = params[:org_domain]
    @data = Freshid::V2::Models::Organisation.find_by_domain(org_domain)
  end

  # Account APIs
  def find_account_by_id
    org_domain = params[:org_domain]
    freshid_account_id = params[:freshid_account_id]
    @data = Freshid::V2::Models::Account.find_by_id(freshid_account_id, org_domain)
  end

  def find_account_by_domain
    org_domain = params[:org_domain]
    account_domain = params[:account_domain]
    @data = Freshid::V2::Models::Account.find_by_domain(account_domain, org_domain)
  end

  def organisation_accounts_by_org_domain
    org_domain = params[:org_domain]
    page_number = params[:page_number]
    page_size = params[:page_size]
    @data = Freshid::V2::Models::Account.organisation_accounts(page_number, page_size, org_domain)
  end

  def user_accounts_by_id
    org_domain = params[:org_domain]
    freshid_user_id = params[:freshid_user_id]
    page_number = params[:page_number]
    page_size = params[:page_size]
    @data = Freshid::V2::Models::Account.user_accounts_by_id(freshid_user_id, page_number, page_size, org_domain)
  end

  def user_accounts_by_email
    org_domain = params[:org_domain]
    page_number = params[:page_number]
    page_size = params[:page_size]
    email = params[:email]
    @data = Freshid::V2::Models::Account.user_accounts_by_email(email, page_number, page_size, org_domain)
  end

  # User APIs

  def find_user_by_id
    org_domain = params[:org_domain]
    freshid_user_id = params[:freshid_user_id]
    @data = Freshid::V2::Models::User.find_by_id(freshid_user_id, org_domain)
  end

  def find_user_by_email
    org_domain = params[:org_domain]
    email = params[:email]
    @data = Freshid::V2::Models::User.find_by_email(email, org_domain)
  end

  def account_users
    org_domain = params[:org_domain]
    freshid_account_id = params[:freshid_account_id]
    fetch_admin_users = params[:fetch_admin_users]
    page_number = params[:page_number]
    page_size = params[:page_size]
    @data = Freshid::V2::Models::User.account_users(freshid_account_id, fetch_admin_users, page_number, page_size, org_domain)
  end

  def modify_admin_rights
    org_domain = params[:org_domain]
    freshid_user_id = params[:freshid_user_id]
    make_admin = params[:make_admin]
    @data = Freshid::V2::Models::User.modify_admin_rights(freshid_user_id, make_admin, org_domain)
  end

  def organisation_admins
    org_domain = params[:org_domain]
    user_id = params[:user_id]
    @data = Freshid::V2::Models::User.organisation_admins(user_id, org_domain)
  end

  def deliver_reset_password_instruction
    org_domain = params[:org_domain]
    redirect_uri = params[:redirect_uri]
    email = params[:email]
    @data = Freshid::V2::Models::User.deliver_reset_password_instruction(email, redirect_uri, org_domain)
  end

  #User links

  def create_user_activation_hash
    org_domain = params[:org_domain]
    redirect_uri = params[:redirect_uri]
    freshid_user_id = params[:freshid_user_id]
    @data = Freshid::V2::Models::UserHash.create_activation_hash(freshid_user_id, redirect_uri, org_domain)
  end

end

class Account < ActiveRecord::Base
  include OmniChannel::Util

  def organisation_domain
    organisation_from_cache.try(:domain)
  end

  def organisation_accounts(org_domain, page_number = 1, page_size = nil)
    Freshid::V2::Models::Account.organisation_accounts(page_number, page_size, org_domain)
  end

  def launch_freshid_with_omnibar(freshid_org_v2_signup = nil)
    unless self.freshid_integration_enabled?
      freshid_org_v2_signup = self.freshid_v2_signup_allowed? if freshid_org_v2_signup.nil?
      freshid_org_v2_signup ? launch(:freshid_org_v2) : launch(:freshid)
    end
    launch(:freshworks_omnibar) if omnibar_signup_allowed?
  end

  def enable_freshid(freshid_org_v2 = nil)
    freshid_org_v2 = self.freshid_v2_signup_allowed? unless freshid_org_v2.present?
    Rails.logger.info "FRESHID Enqueuing worker for migration :: a=#{self.id}, d=#{self.full_domain}"
    freshid_org_v2 ? Freshid::V2::AgentsMigration.perform_async : Freshid::AgentsMigration.perform_async
  end

  def disable_freshid
    Rails.logger.info "FRESHID Enqueuing worker for revert migration :: a=#{self.id}, d=#{self.full_domain}"
    self.freshid_org_v2_enabled? ? Freshid::V2::AgentsMigration.perform_async({ revert_migration: true }) : Freshid::AgentsMigration.perform_async({ revert_migration: true })
  end

  def create_freshid_org_and_account(org_id, join_token, user)
    return unless freshid_enabled?
    response = org_id.present? ? create_freshid_account_with_user_for_org(org_id, join_token, user) : create_freshid_org_with_account_and_user(user)
    sync_user_info_from_freshid(user, response[:user]) if response[:user].present?
    user.enqueue_activation_email
  end

  def create_freshid_account_with_user_for_org(org_id, join_token, user)
    organisation = Freshid::Organisation.new(id: org_id)
    organisation.create_account(join_token, freshid_attributes)
  end

  def create_freshid_org_with_account_and_user(user)
    payload = { organisation: { name: name }, account: freshid_attributes, user: user.freshid_attributes }
    Freshid::Organisation.create(payload)
  end

  def create_freshid_org_without_account_and_user
    Freshid::Organisation.create_for_account(name)
  end

  def map_freshid_org_to_account(org_id)
    Freshid::Organisation.new(id: org_id).map_to_account(full_domain)
  end

  def freshid_attributes
    { name: name, domain: full_domain }
  end

  def sync_user_info_from_freshid(user, user_info)
    freshid_user = Freshid::User.new(user_info)
    user.sync_profile_from_freshid(freshid_user)
    user.save
  end

  def initiate_freshid_migration
    set_others_redis_key(freshid_migration_in_progress_key, Time.now.to_i)
  end

  def freshid_migration_complete
    remove_others_redis_key(freshid_migration_in_progress_key)
  end

  def freshid_migration_in_progress?
    redis_key_exists? freshid_migration_in_progress_key
  end

  # Org v2 methods
  def freshid_integration_enabled?
    self.freshid_enabled? || self.freshid_org_v2_enabled?
  end

  def create_freshid_v2_account(user, join_token = nil, organisation_domain = nil, loop_counter = nil)
    return unless freshid_org_v2_enabled?
    account_creator = Freshid::V2::AccountCreator.new
    if join_token.present?
      account_creator.create_in_existing_org(freshid_attributes, nil, join_token)
    elsif organisation_domain.present?
      account_creator.create_in_existing_org(freshid_attributes, organisation_domain)
    else
      account_creator.create_in_new_org(freshid_org_attributes, freshid_attributes, user.freshid_attributes)
    end
    Rails.logger.info "FRESHID Organisation = #{account_creator.organisation.inspect}, Account = #{account_creator.account.inspect}, User = #{account_creator.user.inspect}"
    if account_creator.success?
      sync_account_org_user_info_from_freshid_v2(user, account_creator.organisation, account_creator.account, account_creator.user)
      user.enqueue_activation_email
    else
      loop_counter = loop_counter || 1
      args = {
        method: "create_account",
        error_code: account_creator.error_code,
        params: {
          user_id: user.try(:id),
          join_token: join_token,
          organisation_domain: organisation_domain,
          loop_counter: loop_counter,
          account_id: self.id
        }
      }
      FreshidRetryWorker.perform_at((2**loop_counter).minutes.from_now, args)
    end
  end

  def sync_account_org_user_info_from_freshid_v2(user, freshid_organisation, freshid_account, freshid_user)
    self.organisation = Organisation.find_or_create_from_freshid_org(freshid_organisation)
    self.freshid_account_id = freshid_account.try(:id)
    save!
    sync_user_info_from_freshid_v2!(user, freshid_user) if freshid_user.present?
  end

  def sync_user_info_from_freshid_v2!(user, freshid_user)
    user.sync_profile_from_freshid(freshid_user)
    user.save
  end

  def freshid_org_attributes
    { name: name, domain: domain, region_code: FRESHID_V2_REGION_CODE }
  end

  def delete_all_users_in_freshid
    self.all_technicians.find_each do |user|
      begin
        user.destroy_freshid_user
      rescue Exception => e
        Rails.logger.error("FRESHID error in removing user email:#{user.email}, account:#{self.id}, uid:#{user.freshid_authorization.uid}, e=#{e.inspect}, backtrace=#{e.backtrace}")
      end
    end
  end

  def create_all_users_in_freshid
    self.all_technicians.find_each do |user|
      begin
        user.create_freshid_user!
      rescue Exception => e
        Rails.logger.error("FRESHID error in creating user email:#{user.email}, user_id:#{user.id}, account:#{self.id}, e=#{e.inspect}, backtrace=#{e.backtrace}")
      end
    end
  end

  # end of FreshID org v2 methods

  def update_account_details_in_freshid(status_changed = false)
    account = self.make_current
    if account.freshid_org_v2_enabled?
      freshid_account_params = {}
      freshid_account_params[:name] = account.name if account.account_name_changed?
      freshid_account_params[:domain] = account.full_domain if account.account_domain_changed?
      freshid_account_params[:status] = freshid_status if status_changed
      return if freshid_account_params.blank?

      account_details_params = { account_id: account.id,
                                 organisation_domain: self.organisation_domain,
                                 freshid_account_params: freshid_account_params }
      account_details_params[:account_domain] = account.account_domain_changed? ? @all_changes[:full_domain].first : account.full_domain
      Freshid::V2::AccountDetailsUpdate.perform_async(account_details_params)
    else
      account_details_params = { name: account.name, account_id: account.id }
      account_details_params[:domain] = account_domain_changed? ? @all_changes[:full_domain].first : account.full_domain
      account_details_params[:new_domain] = account_domain_changed? ? account.full_domain : nil
      Freshid::AccountDetailsUpdate.perform_async(account_details_params)
    end
  end

  def destroy_freshid_account
    if self.freshid_org_v2_enabled?
      organisation_domain = self.organisation_domain
      account_params = {
        account_id: self.id,
        account_domain: self.full_domain,
        organisation_domain: organisation_domain,
        destroy: true
      }
      Freshid::V2::AccountDetailsUpdate.perform_async(account_params)
    else
      account_params = {
        name: self.name,
        account_id: self.id,
        domain: self.full_domain,
        destroy: true
      }
      Freshid::AccountDetailsUpdate.perform_async(account_params)
    end
  end

  alias_method :destroy_freshid_account_on_rollback, :destroy_freshid_account

  def update_freshid?
    freshid_integration_enabled? && (account_domain_changed? || account_name_changed?) && !suppress_freshid_calls
  end

  def sso_enabled_freshid_account?
    sso_enabled? && sso_enabled_changed? && freshid_enabled? && freshdesk_sso_enabled?
  end

  def sso_disabled_not_freshid_account?
    !sso_enabled? && sso_enabled_changed? && !freshid_integration_enabled? && freshid_integration_signup_allowed?
  end

  def freshid_signup_allowed?
    redis_key_exists? FRESHID_NEW_ACCOUNT_SIGNUP_ENABLED
  end

  def freshid_v2_signup_allowed?
    redis_key_exists? FRESHID_V2_NEW_ACCOUNT_SIGNUP_ENABLED
  end
  
  def freshid_integration_signup_allowed?
    freshid_signup_allowed? || freshid_v2_signup_allowed?
  end

  def omnibar_signup_allowed?
    redis_key_exists? FRESHWORKS_OMNIBAR_SIGNUP_ENABLED
  end

  def freshid_migration_not_in_progress?
    !freshid_migration_in_progress?
  end

  def organisation_from_cache
    Organisation.fetch_by_account_id(self.id)
  end

  def remove_organisation_account_mapping
    org_account_mapping = OrganisationAccountMapping.find_by_account_id(self.id)
    org_account_mapping.destroy
  end

  def freshid_custom_policy_enabled?(entity)
    additional_settings = account_additional_settings.additional_settings
    additional_settings[:freshid_custom_policy_configs] && additional_settings[:freshid_custom_policy_configs][entity]
  end

  def freshid_custom_policy_enabled_for_account?
    account_additional_settings.additional_settings[:freshid_custom_policy_configs]
  end

  def create_organisation_bundle(bundle_type_identifier)
    org_info = {
      domain: organisation_domain
    }
    bundle_info = {
      bundle_type_identifier: bundle_type_identifier.to_s
    }
    Freshid::V2::Models::Bundle.create(org_info, bundle_info)
  end

  def update_bundle_id(bundle_id, bundle_name)
    response = update_bundle_details(full_domain, organisation_domain, bundle_id, true)
    unless response.is_error
      account_additional_settings.bundle_details_setter(bundle_id, bundle_name)
      return account_additional_settings.save!
    end
    false
  end

  private

    def freshid_migration_in_progress_key
      FRESHID_MIGRATION_IN_PROGRESS_KEY % {account_id: self.id}
    end

    def freshid_v2_signup?
      @freshid_v2_signup ||= (self.fresh_id_version == Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2)
    end
end

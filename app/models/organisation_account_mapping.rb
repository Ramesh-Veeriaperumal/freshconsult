class OrganisationAccountMapping < ActiveRecord::Base
  include Cache::Memcache::OrganisationAccountMapping
  include OmniChannelDashboard::TouchstoneUtil

  self.primary_key = :id

  not_sharded

  belongs_to :organisation

  after_commit :clear_cache_by_account_id, :clear_account_ids_cache
  after_commit :delete_orphan_organisation, on: :update, if: :organisation_id_changed?
  after_destroy :delete_orphan_organisation
  after_commit :invoke_touchstone_account_worker, if: :omni_bundle_enabled?

  private

    def delete_orphan_organisation
      organisation_id_changes = previous_changes[:organisation_id][0] if previous_changes.present?
      organisation_id = organisation_id_changes || self.organisation_id
      no_of_accounts_mapped = OrganisationAccountMapping.where(organisation_id: organisation_id).count
      Organisation.find_by_id(organisation_id).destroy if no_of_accounts_mapped == 0
    end

    def organisation_id_changed?
      previous_changes.key?(:organisation_id)
    end

    def clear_account_ids_cache
      clear_account_ids_by_organisation_cache(self.organisation_id)
      clear_account_ids_by_organisation_cache(previous_changes[:organisation_id][0]) if previous_changes.key?(:organisation_id)
    end
end

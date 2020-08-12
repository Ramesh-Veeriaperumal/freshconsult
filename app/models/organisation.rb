class Organisation < ActiveRecord::Base
  self.primary_key = :id
  include Cache::Memcache::Organisation
  FRESHSALES = 'freshsales'.freeze
  FRESHCALLER = 'freshcaller'.freeze
  FRESHCHAT = 'freshchat'.freeze
  PAGE_BREAK_COUNT = 10

  not_sharded
  concerned_with :presenter

  after_commit :clear_cache_organisation_id
  after_commit :clear_mapped_account_ids_from_cache
  after_commit :send_activation_email, on: :update, if: :domain_changed?

  def self.fetch_by_account_id(account_id)
    ## OVERRIDDEN ##
    return if account_id.blank?
    key = format(MemcacheKeys::ORGANISATION_BY_ACCOUNT_ID, account_id: account_id)
    MemcacheKeys.fetch(key) do
      OrganisationAccountMapping.find_by_account_id(account_id).try(:organisation)
    end
  end

  def self.fetch_by_organisation_id(organisation_id)
    ## OVERRIDDEN ##
    return if organisation_id.blank?
    key = format(MemcacheKeys::ORGANISATION_BY_ORGANISATION_ID, organisation_id: organisation_id)
    MemcacheKeys.fetch(key) { Organisation.find_by_organisation_id(organisation_id) }
  end

  def mapped_account_ids_from_cache
    key = format(MemcacheKeys::ACCOUNT_ID_BY_ORGANISATION, organisation_id: self.id)
    MemcacheKeys.fetch(key) do
      self.organisation_account_mapping.pluck(:account_id)
    end
  end

  def clear_cache_organisation_id
    key = format(MemcacheKeys::ORGANISATION_BY_ORGANISATION_ID, organisation_id: self.organisation_id)
    MemcacheKeys.delete_from_cache key
  end

  def account_ids
    ## OVERRIDDEN ##
    mapped_account_ids_from_cache
  end

  def clear_mapped_account_ids_from_cache
    mapped_account_ids = self.organisation_account_mapping.pluck(:account_id)
    mapped_account_ids.each do |account_id|
      key = format(ORGANISATION_BY_ACCOUNT_ID, account_id: account_id)
      MemcacheKeys.delete_from_cache key
    end
  end

  def organisation_freshsales_account_url
    freshsales_url = nil
    organisation_domain = alternate_domain || domain
    if organisation_domain
      freshid_accounts = Account.current.organisation_accounts(organisation_domain)
      products = product_details_from_cache(organisation_domain)
      Rails.logger.info "Response from Freshid, Product: #{products.inspect}"
      if products.present? && freshid_accounts.present?
        freshid_accounts[:accounts].each do |freshid_account|
          product_name = products['productList'].find { |product| product['id'] == freshid_account[:product_id] }['name']
          if product_name == FRESHSALES
            freshsales_url = freshid_account[:domain]
            break
          end
        end
      end
    end
    freshsales_url
  end

  def omni_accounts_present?
    organisation_domain = alternate_domain || domain
    products = product_details_from_cache(organisation_domain)
    page_counter = 1
    loop do
      organisation_accounts = Account.current.organisation_accounts(organisation_domain, page_counter)
      if products.present? && organisation_accounts.present?
        freshcaller_product_object = fetch_product_object_by_name(products, FRESHCALLER)
        freshchat_product_object = fetch_product_object_by_name(products, FRESHCHAT)
        organisation_accounts[:accounts].map do |org_account|
          return true if [freshcaller_product_object['id'], freshchat_product_object['id']].include?(org_account[:product_id])
        end
      end
      if page_counter == PAGE_BREAK_COUNT
        Rails.logger.info "Organisation accounts fetch page limit reached for account :: #{Account.current.id} "
        break
      end
      break unless organisation_accounts[:has_more]

      page_counter += 1
    end
    false
  end

  private

    def domain_changed?
      previous_changes.key?(:domain)
    end

    def fetch_product_object_by_name(products, name)
      products['productList'].find { |product| product['name'].downcase == name }
    end

    def send_activation_email
      account_ids.each do |account_id|
        begin
          Sharding.admin_select_shard_of(account_id) do
            account = Account.find(account_id).make_current
            account.technicians.where(active: false).find_each do |user|
              user.enqueue_activation_email
            end
          end
        rescue Exception => e
          Rails.logger.error("FRESHID exception in sending activation email: #{e.message}, #{e.backtrace}")
        ensure
          Account.reset_current_account
        end
      end
    end
end

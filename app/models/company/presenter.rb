class Company < ActiveRecord::Base
  include RepresentationHelper
  include CustomFieldsHelper
  DATETIME_FIELDS = [:created_at, :updated_at].freeze
  FLEXIFIELD_PREFIXES = ['cf_str', 'cf_date', 'cf_text', 'cf_int', 'cf_boolean'].freeze

  acts_as_api

  api_accessible :central_publish do |u|
    u.add :id
    u.add :name
    u.add :cust_identifier
    u.add :account_id
    u.add :description
    u.add proc { |x| x.custom_field_hash('company') }, as: :custom_fields
    u.add :sla_policy_id
    u.add :note
    u.add :domain_list_with_id, as: :domains
    u.add :delta
    u.add :import_id
    #avatar is set as nil for prestaging only,please do not set as nil for falcon-presaging
    u.add nil, as: :avatar
    u.add :health_score
    u.add :account_tier
    u.add :industry
    u.add :renewal_date
    DATETIME_FIELDS.each do |key|
      u.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def model_changes_for_central
    changes = @model_changes
    flexifield_changes = changes.select { |k, v| k.to_s.starts_with?(*FLEXIFIELD_PREFIXES) }
    return changes if flexifield_changes.blank?
    company_custom_field_name_mapping = account.company_form.
    company_fields_from_cache.each_with_object({}) { |entry, hash| hash[entry.column_name] = entry.name }
    flexifield_changes.each_pair do |key, val|
      changes[company_custom_field_name_mapping[key.to_s]] = val
      changes.delete(key)
    end
    changes
  end

  def self.central_publish_launched?
    Account.current.launched? :company_central_publish
  end

  def relationship_with_account
    'companies'
  end

  def central_publish_worker_class
    'CentralPublishWorker::CompanyWorker'
  end

  def event_info(_action)
    { ip_address: Thread.current[:current_ip] }
  end
end

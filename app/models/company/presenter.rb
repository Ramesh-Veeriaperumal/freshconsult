class Company < ActiveRecord::Base
  include RepresentationHelper
  DATETIME_FIELDS = [:created_at, :updated_at].freeze
  FLEXIFIELD_PREFIXES = ['cf_str', 'cf_date', 'cf_text', 'cf_int', 
    'cf_boolean'].freeze

  acts_as_api

  api_accessible :central_publish do |u|
    u.add :id
    u.add :name
    u.add :cust_identifier
    u.add :account_id
    u.add :description
    u.add :custom_fields_hash, as: :custom_fields
    u.add :sla_policy_id
    u.add :note
    u.add :domain_list, as: :domains
    u.add :delta
    u.add :import_id
    u.add :avatar
    u.add :health_score
    u.add :account_tier
    u.add :industry
    u.add :renewal_date
    DATETIME_FIELDS.each do |key|
      u.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def custom_fields_hash
    custom_company_fields.inject([]) do |arr, field|
      begin
        field_value = safe_send(field.name)
        arr.push({
          ff_alias:  field.name,
          ff_name:  field.column_name,
          ff_coltype:  field.field_type.to_s,
          field_value: field.field_type == 'custom_date' ? 
          utc_format(field_value) : field_value
        })
      rescue Exception => e
        Rails.logger.error "Error while fetching company custom 
        field value - #{e}\n#{e.message}\n#{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e)
      end
    end
  end

  def custom_company_fields
    account.company_form.company_fields_from_cache.reject { |field| field.column_name == 'default' }
  end

  def model_changes_for_central
    changes = @model_changes
    flexifield_changes = changes.select { |k, v| k.to_s.starts_with?(*FLEXIFIELD_PREFIXES) }
    return changes if flexifield_changes.blank?
    company_custom_field_name_mapping = account.company_form.
    company_fields_from_cache.each_with_object({}) { |entry, hash| hash[entry.column_name] = entry.name }
    flexifield_changes.each_pair do |key, val|
      changes[company_custom_field_name_mapping[key.to_s]] = val
    end
    changes.except(*flexifield_changes.keys)
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
end


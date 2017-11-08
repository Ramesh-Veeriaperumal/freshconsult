class CompanyDecorator < ApiDecorator
  delegate :id, :name, :description, :note, :health_score,
           :account_tier, :industry, to: :record
  delegate :tam_default_company_fields_enabled?, to: 'Account.current'

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
  end

  def custom_fields
    # @name_mapping will be nil for READ requests, hence it will computed for the first
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = v }
    custom_fields_hash
  end

  def renewal_date
    utc_format(record.renewal_date)
  end

  def domains
    record.domains.nil? ? [] : record.domains.split(',')
  end
end

class ContactDecorator
  attr_accessor :record

  delegate :id, :active, :address, :company_id, :deleted, :description, :email, :job_title, :language,
           :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager, :avatar, :created_at,
           :updated_at, to: :record

  def initialize(record, options)
    @record = record
    @name_mapping = options[:name_mapping]
  end

  def tags
    record.tags.map(&:name)
  end

  def custom_fields
    # @name_mapping will be nil for READ requests
    @name_mapping ||= record.custom_field.each_with_object({}) { |cf, hash| hash[cf.name] = CustomFieldDecorator.without_cf(cf.name) }
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k.to_sym]] = v }
    custom_fields_hash
  end
end

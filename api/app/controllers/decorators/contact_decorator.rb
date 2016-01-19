class ContactDecorator < ApiDecorator
  delegate :id, :active, :address, :company_id, :deleted, :description, :email, :job_title, :language,
           :mobile, :name, :phone, :time_zone, :twitter_id, :client_manager, :avatar, to: :record

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
  end

  def tags
    record.tags.map(&:name)
  end

  def custom_fields
    # @name_mapping will be nil for READ requests
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = v }
    custom_fields_hash
  end
end

class ContactDecorator < ApiDecorator
  delegate :id, :active, :address, :company_id, :deleted, :description, :customer_id, :email, :job_title, :language,
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

  def other_emails
    record.user_emails.reject(&:primary_role).map(&:email)
  end
  
  def avatar_hash
    # Should be cached
    return nil unless avatar.present?
    {
      id: avatar.id,
      name: avatar.content_file_name,
      content_type: avatar.content_content_type,
      size: avatar.content_file_size,
      created_at: avatar.created_at.try(:utc),
      updated_at: avatar.updated_at.try(:utc),
      avatar_url: avatar.attachment_url_for_api
    }
  end
end

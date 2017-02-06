class ContactDecorator < ApiDecorator
  delegate  :id, :active, :address, :deleted, :description,
            :customer_id, :email, :job_title, :language, :mobile,
            :name, :phone, :time_zone, :twitter_id, :avatar, to: :record
  delegate :company_id, :client_manager, to: :default_company, allow_nil: true
  delegate :multiple_user_companies_enabled?, to: 'Account.current'

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
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = v } if @name_mapping.present?
    custom_fields_hash
  end

  def other_emails
    record.user_emails.reject(&:primary_role).map(&:email)
  end

  def default_company
    record.default_user_company
  end

  def other_companies
    others = record.user_companies - [default_company]
    others.map{|x| {company_id: x.company_id, view_all_tickets: x.client_manager}}
  end
  
  def avatar_hash
    # Should be cached
    return nil unless avatar.present?
    AttachmentDecorator.new(avatar).to_hash.merge(thumb_url: record.avatar.attachment_url_for_api(true, :thumb))
  end

  def to_hash
    User.current.privilege?(:view_contacts) ? to_full_hash : to_restricted_hash
  end

  private

    def to_full_hash
      response_hash = {
        id: id,
        active: active,
        address: address,
        company_id: company_id,
        description: description,
        email: email,
        job_title: job_title,
        language: language,
        mobile: mobile,
        name: name,
        phone: phone,
        time_zone: time_zone,
        twitter_id: twitter_id,
        custom_fields: custom_fields,
        other_emails: other_emails,
        tags: tags,
        created_at: created_at.try(:utc),
        updated_at: updated_at.try(:utc),
        avatar: avatar_hash
      }
      response_hash.merge!(deleted: true) if record.deleted
      response_hash
    end

    def to_restricted_hash
      {
        id: id,
        name: name,
        avatar: avatar_hash
      }
    end
end

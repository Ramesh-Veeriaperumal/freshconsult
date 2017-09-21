class ContactDecorator < ApiDecorator
  include Helpdesk::RequesterWidgetHelper

  delegate  :id, :active, :address, :company_name, :deleted, :description,
            :customer_id, :email, :job_title, :language, :mobile,
            :name, :phone, :time_zone, :twitter_id, :avatar, :whitelisted, :unique_external_id, :fb_profile_id, to: :record
  delegate :company_id, :client_manager, to: :default_company, allow_nil: true
  delegate :multiple_user_companies_enabled?, :unique_contact_identifier_enabled?, to: 'Account.current'

  def initialize(record, options)
    super(record)
    @include_company_info = true
    @name_mapping = options[:name_mapping]
    @company_name_mapping = options[:company_name_mapping]
    @sideload_options = options[:sideload_options] || []
  end

  def tags
    record.tags.map(&:name)
  end

  def custom_fields
    # @name_mapping will be nil for READ requests
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = utc_format(v) } if @name_mapping.present?
    custom_fields_hash
  end

  def other_emails
    record.user_emails.reject(&:primary_role).map(&:email)
  end

  def default_company
    @default_user_company ||= record.user_companies.select(&:default).first
  end

  def other_companies
    others = record.user_companies - [default_company]
    others.map { |x| { company_id: x.company_id, view_all_tickets: x.client_manager } }
  end

  def other_companies_hash
    if @sideload_options.include?('company')
      record.user_companies.map do |c|
        company_hash(c) if c.company.present? && !c.default
      end.compact
    else
      record.user_companies.map(&:company_id).reject { |x| x == company_id }
    end
  end

  def avatar_hash
    # Should be cached
    return nil unless avatar.present?
    AttachmentDecorator.new(avatar).to_hash.merge(thumb_url: record.avatar.attachment_url_for_api(true, :thumb))
  end

  def to_hash
    (User.current.privilege?(:view_contacts) || User.current.id == id) ? to_full_hash : to_restricted_hash
  end

  def to_search_hash
    {
      id: id,
      name: name,
      email: email,
      phone: phone,
      company_id: company_id,
      company_name: company_name,
      avatar: avatar_hash,
      twitter_id: twitter_id
    }
  end

  def full_requester_hash
    @include_company_info = @sideload_options.include?('company')
    req_hash = to_full_hash.except(:company_id)
    req_hash[:id] = record.id
    req_hash
  end

  def restricted_requester_hash
    req_hash = construct_hash(requester_widget_contact_fields, record)
    req_hash[:has_email] = record.email.present?
    req_hash[:twitter_id] = twitter_id if !req_hash.key(:twitter_id) && twitter_id.present?
    req_hash
  end

  private

    def to_full_hash
      record.agent? ? agent_info : customer_info
    end

    def to_restricted_hash
      {
        id: id,
        name: name,
        avatar: avatar_hash
      }
    end

    def agent_info
      {
        active: active,
        email: email,
        job_title: job_title,
        language: language,
        mobile: mobile,
        name: name,
        phone: phone,
        time_zone: time_zone,
        local_time: Time.now.in_time_zone(time_zone).strftime('%I:%M %p'),
        avatar: avatar_hash
      }
    end

    def customer_info
      response_hash = agent_info.merge(id: id,
                                       address: address,
                                       company_id: company_id,
                                       view_all_tickets: client_manager,
                                       description: description,
                                       twitter_id: twitter_id,
                                       other_emails: other_emails,
                                       tags: tags,
                                       whitelisted: whitelisted,
                                       created_at: created_at.try(:utc),
                                       updated_at: updated_at.try(:utc),
                                       facebook_id: fb_profile_id,
                                       blocked: record.blocked?,
                                       spam: record.spam?,
                                       deleted: record.deleted)
      response_hash[:custom_fields] = custom_fields if custom_fields.present?
      response_hash[:company] = company_hash(default_company) if @sideload_options.include?('company') && default_company.present? && default_company.company.present?
      response_hash[:other_companies] = other_companies_hash if multiple_user_companies_enabled?
      response_hash
    end

    def company_hash(uc)
      {
        id: uc.company_id,
        view_all_tickets: uc.client_manager,
        name: uc.company.name
      }
    end

    def construct_hash(req_widget_fields, obj)
      default_fields = req_widget_fields.select(&:default_field?)
      custom_fields = req_widget_fields.reject(&:default_field?)
      ret_hash = widget_fields_hash(obj, default_fields)
      ret_hash[:custom_fields] = widget_fields_hash(obj, custom_fields, true) if custom_fields.present?
      ret_hash[:id] = obj.id
      ret_hash
    end

    def widget_fields_hash(obj, fields, name_mapping = false)
      return fields.inject({}) { |a, e| a.merge(e.name => obj.send(e.name)) } unless name_mapping
      fields.inject({}) { |a, e| a.merge(CustomFieldDecorator.display_name(e.name) => obj.send(e.name)) }
    end

    def current_account
      Account.current
    end
end

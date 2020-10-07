class ContactDecorator < ApiDecorator
  include Helpdesk::RequesterWidgetHelper

  delegate  :id, :active, :address, :company_name, :deleted, :description,
            :customer_id, :email, :job_title, :language, :mobile,
            :name, :phone, :time_zone, :twitter_id, :fb_profile_id, :external_id,
            :avatar, :whitelisted, :unique_external_id, :twitter_requester_fields, :fb_profile_id, :import_id,
            :deleted_at, :blocked, :blocked_at, :whitelisted, :parent_id, :extn,
            :preferences, :password_salt, :user_role, :delta, :privileges,
            :crypted_password, :last_login_at, :current_login_at, :history_column,
            :last_login_ip, :current_login_ip, :login_count, :second_email,
            :failed_login_count, :last_seen_at, :posts_count, :preferred_source, :last_csat_rating, :twitter_requester_handle_id, to: :record

  delegate :company_id, :client_manager, to: :default_company, allow_nil: true
  delegate :multiple_user_companies_enabled?, :unique_contact_identifier_enabled?, :twitter_api_compliance_enabled?, to: 'Account.current'

  FIELD_NAME_MAPPING = {
    'tag_names' => 'tags'
  }

  EXCEPT_LIST = %w[id cust_identifier account_id created_at updated_at sla_policy_id delta import_id].freeze

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
    @company_name_mapping = options[:company_name_mapping]
    @sideload_options = options[:sideload_options] || []
    @additional_info = options[:additional_info]
  end

  def tags
    record.tags.map(&:name)
  end

  def custom_fields
    # @name_mapping will be nil for READ requests
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = format_date(v) } if @name_mapping.present?
    custom_fields_hash
  end

  def raw_custom_fields
    record.custom_field
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

  def company_info
    ret_hash = {}
    ret_hash[:company] = company_hash(default_company) if @sideload_options.include?('company') && default_company.present? && default_company.company.present?
    ret_hash[:other_companies] = other_companies_hash if multiple_user_companies_enabled? && company_id.present?
    ret_hash
  end

  def fetch_primary_company_details
    if record.company.present?
      primary_company = record.company.attributes.except!(*EXCEPT_LIST)
      primary_company['domains'] = record.company.company_domains.map(&:domain)
      primary_company.merge!(record.company.tam_fields) if current_account
                                                           .tam_default_fields_enabled?
      primary_company.merge!(record.company.custom_field)
      { primary_company: primary_company }
    else
      { primary_company: nil }
    end
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
    AttachmentDecorator.new(avatar).to_hash
  end

  def to_hash
    (app_current? || User.current.privilege?(:view_contacts) || User.current.id == id) ? to_full_hash : to_restricted_hash
  end

  def to_agent_hash
    app_current? || User.current.privilege?(:manage_users) || User.current.id == id ? to_full_hash : to_restricted_hash
  end

  def other_company_items
    record.user_companies.preload(:company).map do |c|
      company_hash(c) if c.company.present? && !c.default
    end.compact
  end

  def to_search_hash
    response_hash = {
      id: id,
      name: name,
      email: email,
      phone: phone,
      mobile: mobile,
      company_id: company_id,
      company_name: company_name,
      avatar: avatar_hash,
      twitter_id: twitter_id,
      facebook_id: fb_profile_id,
      external_id: external_id,
      unique_external_id: unique_external_id,
      other_emails: other_emails
    }
    response_hash[:other_companies] = other_company_items if multiple_user_companies_enabled?
    response_hash
  end

  def restricted_requester_hash
    req_hash = construct_hash(requester_widget_contact_fields, record)
    req_hash[:has_email] = record.email.present? if !req_hash.key?(:email)
    req_hash[:active] = record.active
    req_hash
  end

  def other_requester_fields(req_hash)
    fields_hash = {}
    fields_hash[:email] = email if !req_hash.key?(:email) && email.present?
    fields_hash[:other_emails] = other_emails if other_emails.present?
    fields_hash[:phone] = phone if !req_hash.key?(:phone) && phone.present?
    fields_hash[:mobile] = mobile if !req_hash.key?(:mobile) && mobile.present?
    fields_hash[:twitter_id] = twitter_id if !req_hash.key?(:twitter_id) && twitter_id.present?
    fields_hash[:facebook_id] = fb_profile_id if !req_hash.key?(:facebook_id) && fb_profile_id.present?
    fields_hash[:unique_external_id] = unique_external_id if !req_hash.key?(:unique_external_id) && unique_external_id.present?
    fields_hash[:external_id] = external_id if !req_hash.key?(:external_id) && external_id.present?
    fields_hash
  end

  def requester_hash
    return agent_info.merge(id: id) if record.agent?
    req_hash = restricted_requester_hash.merge(company_info)
    req_hash[:avatar] = avatar_hash
    req_hash.merge!(other_requester_fields(req_hash.symbolize_keys))
    req_hash
  end

  def to_ocr_hash
    {
      name: name,
      email: email   
    }
  end

  def channel_v2_attributes
    channel_v2_hash if channel_v2_api? && @additional_info
  end

  def company_info_for_search
    ret_hash = {}
    ret_hash[:company] = company_hash(default_company) if default_company.present? && default_company.company.present?
    if multiple_user_companies_enabled? && company_id.present?
      ret_hash[:other_companies] = record.user_companies.map do |c|
        company_hash(c) if c.company.present? && !c.default
      end.compact
    end
    ret_hash
  end

  def twitter_id
    Account.current.twitter_api_compliance_enabled? && public_v2_api? ? twitter_requester_handle_id : record.twitter_id
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
      info = {
        active: active,
        email: email,
        job_title: job_title,
        language: language,
        mobile: mobile,
        name: name,
        phone: phone,
        time_zone: time_zone,
        avatar: avatar_hash
      }
      info.merge!({
        id: id,
        deleted_agent: true,
        deleted: true
      }) if record.deleted?
      info
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
                                       external_id: external_id,
                                       unique_external_id: unique_external_id,
                                       blocked: record.blocked?,
                                       spam: record.spam?,
                                       deleted: record.deleted,
                                       was_agent: record.was_agent?,
                                       agent_deleted_forever: record.agent_deleted_forever?,
                                       marked_for_hard_delete: record.marked_for_hard_delete?,
                                       parent_id: record.parent_id,
                                       csat_rating: record.last_csat_rating,
                                       preferred_source: record.preferred_source)
      response_hash.merge!(record.twitter_requester_fields)
      response_hash[:custom_fields] = custom_fields if custom_fields.present?
      response_hash.merge(company_info)
    end

    def channel_v2_hash
      {
        import_id: import_id,
        deleted_at: deleted_at,
        blocked: blocked,
        blocked_at: blocked_at,
        whitelisted: whitelisted,
        external_id: external_id,
        parent_id: parent_id,
        crypted_password: crypted_password,
        password_salt: password_salt,
        last_login_at: last_login_at,
        current_login_at: current_login_at,
        last_login_ip: last_login_ip,
        current_login_ip: current_login_ip,
        login_count: login_count,
        failed_login_count: failed_login_count,
        second_email: second_email,
        last_seen_at: last_seen_at,
        preferences: preferences,
        posts_count: posts_count,
        user_role: user_role,
        delta: delta,
        privileges: privileges,
        extn: extn,
        history_column: history_column
      }
    end

    def company_hash(uc)
      {
        id: uc.company_id,
        view_all_tickets: uc.client_manager,
        name: uc.company.name,
        avatar: CompanyDecorator.new(uc.company, {}).avatar_hash
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
      return fields.inject({}) { |a, e| a.merge(field_mapping(e)) } unless name_mapping
      fields.inject({}) { |a, e| a.merge(CustomFieldDecorator.display_name(e.name) => format_date(obj.safe_send(e.name))) }
    end

    def field_mapping(field)
      mapped_field = FIELD_NAME_MAPPING[field.name.to_s]
      mapped_field ? { mapped_field => safe_send("#{mapped_field}") } : {field.name => record.safe_send(field.name)}
    end

    def current_account
      Account.current
    end
end

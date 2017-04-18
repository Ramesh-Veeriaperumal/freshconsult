module ContactConstants
  ARRAY_FIELDS = ['tags', 'other_emails', 'other_companies']
  HASH_FIELDS = ['custom_fields']
  ALLOWED_OTHER_COMPANIES_FIELDS = ['company_id', 'view_all_tickets']
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS

  CONTACT_FIELDS = %w(active address avatar view_all_tickets company_id description
                      email job_title language mobile name other_companies
                      other_emails phone time_zone twitter_id unique_external_id).freeze |
                    ARRAY_FIELDS | HASH_FIELDS |
                    ['other_companies' =>  ALLOWED_OTHER_COMPANIES_FIELDS]

  MAKE_AGENT_FIELDS = %w(occasional group_ids role_ids ticket_scope signature).freeze
  STATES = %w( verified unverified deleted blocked ).freeze

  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w( custom_field ).freeze

  INDEX_FIELDS = %w( state email phone mobile company_id _updated_since unique_external_id).freeze

  SCOPE_BASED_ON_ACTION = {
    'update'  => { deleted: false, blocked: false },
    'destroy' => { deleted: false, blocked: false },
    'make_agent' => { deleted: false, blocked: false },
    'restore' => { deleted: true, blocked: false }
  }.freeze

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024

  MAILER_DAEMON_REGEX = /MAILER-DAEMON@(.+)/i.freeze

  # Only xxx.jpg and xxx.png are allowed to upload
  AVATAR_EXT = %w( .jpg .jpeg .jpe .png ).freeze
  AVATAR_CONTENT = { '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.jpe' => 'image/jpeg', '.png' => 'image/png' }.freeze

  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name).freeze

  LANGUAGES = I18n.available_locales.map(&:to_s).freeze

  # Max other email count excluding the primary email
  MAX_OTHER_EMAILS_COUNT = (User::MAX_USER_EMAILS - 1)

  # Max other company count excluding the default company
  MAX_OTHER_COMPANIES_COUNT = (User::MAX_USER_COMPANIES - 1)

  # Routes that doesn't accept any params
  NO_PARAM_ROUTES = %w(restore).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(address email job_title language name mobile phone time_zone tags twitter_id custom_fields other_emails unique_external_id).freeze

  # Wrap parameters args
  WRAP_PARAMS = [:api_contact, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    make_agent: [:json]
  }.freeze

  FIELD_MAPPINGS = {
    company_name: :company_id,
    default_user_company: :company_id,
    company: :company_id,
    :"primary_email.email" => :email, base: :email
  }.freeze

end.freeze

module ContactConstants
  ARRAY_FIELDS = %w(tags other_emails other_companies).freeze
  HASH_FIELDS = %w(custom_fields).freeze
  ALLOWED_OTHER_COMPANIES_FIELDS = %w(company_id view_all_tickets).freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  CONTACT_FIELDS = %w(active address avatar avatar_id view_all_tickets company_id description
                      email job_title language mobile name other_companies
                      other_emails phone time_zone twitter_id unique_external_id).freeze |
                   ARRAY_FIELDS | HASH_FIELDS |
                   ['other_companies' => ALLOWED_OTHER_COMPANIES_FIELDS]
  MAKE_AGENT_FIELDS = %w[occasional group_ids role_ids ticket_scope signature type].freeze
  STATES = %w(verified unverified deleted blocked).freeze
  QUICK_CREATE_FIELDS = %w(name email phone company_name).freeze

  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w(custom_field).freeze

  # INDEX_FIELDS = %w(state email phone mobile company_id tag _updated_since unique_external_id query_hash include filter).freeze
  INDEX_FIELDS = ['state', 'email', 'phone', 'mobile', 'company_id', 'tag', '_updated_since', 'unique_external_id', 'query_hash', 'include', 'filter'].freeze
  SHOW_FIELDS = %w(include).freeze
  MERGE_ARRAY_FIELDS = ['secondary_contact_ids'].freeze
  MERGE_FIELDS = %w[primary_contact_id contact].freeze | MERGE_ARRAY_FIELDS
  EXPORT_ARRAY_FIELDS = %w[default_fields custom_fields].freeze
  EXPORT_FIELDS = %w[fields].freeze
  CHANNEL_INDEX_FIELDS = INDEX_FIELDS | %w[twitter_id facebook_id].freeze

  SCOPE_BASED_ON_ACTION = {
    'update'  => { deleted: false, blocked: false },
    'destroy' => { deleted: false, blocked: false },
    'make_agent' => { deleted: false, blocked: false },
    'restore' => { deleted: true, blocked: false }
  }.freeze

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024

  MAILER_DAEMON_REGEX = /MAILER-DAEMON@(.+)/i

  # Only xxx.jpg and xxx.png are allowed to upload
  AVATAR_EXT = %w(.jpg .jpeg .jpe .png).freeze
  AVATAR_CONTENT = { '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.jpe' => 'image/jpeg', '.png' => 'image/png' }.freeze

  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name).freeze

  LANGUAGES = I18n.available_locales.map(&:to_s).freeze

  BULK_ACTION_METHODS = [:bulk_delete, :bulk_restore, :bulk_send_invite, :bulk_whitelist].freeze

  LOAD_OBJECT_EXCEPT = [:merge, :export, :quick_create, :export_details].freeze + BULK_ACTION_METHODS

  # Max other email count excluding the primary email
  MAX_OTHER_EMAILS_COUNT = (User::MAX_USER_EMAILS - 1)

  # Max other company count excluding the default company
  MAX_OTHER_COMPANIES_COUNT = (User::MAX_USER_COMPANIES - 1)

  MERGE_VALIDATIONS = [['emails', User::MAX_USER_EMAILS, 'emails'],
                       ['twitter_id', 1, 'Twitter User'],
                       ['fb_profile_id', 1, 'Facebook User'],
                       ['external_id', 1, 'Ecommerce User or Mobihelp User'],
                       ['mobile', 1, 'mobile phone'],
                       ['phone', 1, 'work phone']].freeze
  # [Attribute, limit, message] ["phone", 1, "Phone User"]
  # Routes that doesn't accept any params
  MERGE_KEYS = [:phone, :mobile, :twitter_id, :fb_profile_id, :external_id, :unique_external_id].freeze
  MERGE_ARRAY_KEYS = [:other_emails, :company_ids].freeze
  MERGE_CONTACT_FIELDS = MERGE_KEYS | MERGE_ARRAY_KEYS | [:email]
  MERGE_MANDATORY_FIELDS = MERGE_KEYS | [:email]
  NO_PARAM_ROUTES = %w(restore).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(address email job_title language name mobile phone time_zone tags twitter_id custom_fields other_emails unique_external_id).freeze

  # Wrap parameters args
  WRAP_PARAMS = [:api_contact, exclude: [], format: [:json, :multipart_form]].freeze
  EMBER_WRAP_PARAMS = [:contact, exclude: [], format: [:json, :multipart_form]].freeze
  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form],
    make_agent: [:json],
    bulk_delete: [:json],
    bulk_restore: [:json],
    bulk_send_invite: [:json],
    bulk_whitelist: [:json]
  }.freeze

  FIELD_MAPPINGS = {
    company_name: :company_id,
    default_user_company: :company_id,
    company: :company_id,
    :"primary_email.email" => :email, base: :email,
    attachment_ids: :avatar_id
  }.freeze

  MERGE_FIELD_MAPPINGS = {
    emails: :other_emails
  }.freeze

  NO_CONTENT_TYPE_REQUIRED = [:restore, :send_invite].freeze

  PRELOAD_OPTIONS = {
    bulk_delete: [:user_emails, { user_companies: [:company] }, :default_user_company, :flexifield, :primary_email, :roles, :authorizations],
    bulk_restore: [:user_emails, { user_companies: [:company] }, :default_user_company, :flexifield, :primary_email, :roles],
    bulk_send_invite: [:flexifield, :user_companies, :avatar, :default_user_company, :roles],
    bulk_whitelist: []
  }.freeze

  SIDE_LOADING = %w(company).freeze

  VALIDATION_CLASS = 'ContactValidation'.freeze
  DELEGATOR_CLASS = 'ContactDelegator'.freeze
end.freeze

module ContactConstants
  ARRAY_FIELDS = %w(tags other_emails).freeze
  HASH_FIELDS = %w(custom_fields).freeze
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  CONTACT_FIELDS = %w(address avatar avatar_id view_all_tickets company_id description email job_title language mobile name other_emails phone time_zone twitter_id).freeze | ARRAY_FIELDS | HASH_FIELDS

  MAKE_AGENT_FIELDS = %w(occasional group_ids role_ids ticket_scope signature).freeze
  STATES = %w(verified unverified deleted blocked).freeze

  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w(company_id custom_field).freeze

  INDEX_FIELDS = %w(state email phone mobile company_id tag).freeze
  MERGE_ARRAY_FIELDS = ['target_ids'].freeze
  MERGE_FIELDS = %w(primary_id).freeze | MERGE_ARRAY_FIELDS
  EXPORT_CSV_ARRAY_FIELDS = %w(default_fields custom_fields).freeze
  EXPORT_CSV_FIELDS = EXPORT_CSV_ARRAY_FIELDS

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

  LOAD_OBJECT_EXCEPT = [:merge, :export_csv].freeze + BULK_ACTION_METHODS

  # Max other email count excluding the primary email
  MAX_OTHER_EMAILS_COUNT = 4

  MERGE_VALIDATIONS = [['emails', 5, 'emails'], ['twitter_id', 1, 'Twitter User'],
                       ['fb_profile_id', 1, 'Facebook User'], ['external_id', 1, 'Ecommerce User or Mobihelp User'],
                       ['company_names', 20, 'companies'], ['mobile', 1, 'mobile phone'], ['phone', 1, 'work phone']].freeze # [Attribute, limit, message] ["phone", 1, "Phone User"]
  # Routes that doesn't accept any params
  NO_PARAM_ROUTES = %w(restore).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(address email job_title language name mobile phone time_zone tags twitter_id custom_fields other_emails).freeze

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

  FIELD_MAPPINGS = { company_name: :company_id, default_user_company: :company_id, company: :company_id, :"primary_email.email" => :email, base: :email, attachment_ids: :avatar_id }.freeze

  NO_CONTENT_TYPE_REQUIRED = [:restore, :send_invite].freeze

  VALIDATION_CLASS = 'ContactValidation'.freeze
  DELEGATOR_CLASS = 'ContactDelegator'.freeze
end.freeze

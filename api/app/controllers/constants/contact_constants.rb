module ContactConstants
  ARRAY_FIELDS = ['tags']
  HASH_FIELDS = ['custom_fields']
  COMPLEX_FIELDS = ARRAY_FIELDS | HASH_FIELDS
  CONTACT_FIELDS = %w(address avatar view_all_tickets company_id description email job_title language mobile name phone time_zone twitter_id tags).freeze | ARRAY_FIELDS.map { |x| Hash[x, [nil]] } | HASH_FIELDS

  STATES = %w( verified unverified all deleted blocked ).freeze

  INDEX_FIELDS = %w( state email phone mobile company_id ).freeze

  DELETED_SCOPE = {
    'update' => false,
    'destroy' => false,
    'make_agent' => false
  }.freeze

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024

  MAILER_DAEMON_REGEX = /MAILER-DAEMON@(.+)/i.freeze

  # Only xxx.jpg and xxx.png are allowed to upload
  AVATAR_EXT = %w( .jpg .jpeg .jpe .png ).freeze
  AVATAR_CONTENT = { '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.jpe' => 'image/jpeg', '.png' => 'image/png' }.freeze

  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name).freeze

  LANGUAGES = I18n.available_locales.map(&:to_s).freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(address email job_title language name mobile phone time_zone tags twitter_id custom_fields).freeze

  # Wrap parameters args
  WRAP_PARAMS = [:api_contact, exclude: [], format: [:json, :multipart_form]].freeze

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }.freeze

  DEFAULT_FIELD_VALIDATIONS = {
    job_title:  { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } },
    language: { custom_inclusion: { in: ContactConstants::LANGUAGES } },
    tag_names:  { data_type: { rules: Array, allow_nil: false }, array: { data_type: { rules: String }, length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING, message: :too_long } }, string_rejection: { excluded_chars: [','] } },
    time_zone: { custom_inclusion: { in: ContactConstants::TIMEZONES } },
    phone: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } },
    mobile: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } },
    address: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } },
    twitter_id: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } },
    email: { format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }
  }.freeze

  FIELD_MAPPINGS = { company_name: :company_id, tag_names: :tags, company: :company_id, 'primary_email.email'.to_sym => :email, base: :email }.freeze
end.freeze

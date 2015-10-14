module ContactConstants
  ARRAY_FIELDS = [{ 'tags' => [] }]
  CONTACT_FIELDS = %w(address avatar client_manager company_id description email job_title language mobile name phone time_zone twitter_id tags custom_fields) | ARRAY_FIELDS

  STATES = %w( verified unverified all deleted blocked )

  INDEX_FIELDS = %w( state email phone mobile company_id )

  DELETED_SCOPE = {
    'update' => false,
    'destroy' => false,
    'make_agent' => false
  }

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024

  MAILER_DAEMON_REGEX = /MAILER-DAEMON@(.+)/i

  # Only xxx.jpg and xxx.png are allowed to upload
  AVATAR_EXT = %w( .jpg .jpeg .jpe .png )
  AVATAR_CONTENT = { ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".jpe" => "image/jpeg",".png" => "image/png" }

  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name)

  LANGUAGES = I18n.available_locales.map(&:to_s)

  FIELDS_TO_BE_STRIPPED = %w(address email job_title language name mobile phone time_zone tags twitter_id custom_fields)

  # Wrap parameters args
  WRAP_PARAMS = [:api_contact, exclude: [], format: [:json, :multipart_form]]

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }

  DEFAULT_FIELD_VALIDATIONS = {
        client_manager: { data_type: { rules: 'Boolean', ignore_string: :allow_string_param }},
        job_title:  { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        language: { custom_inclusion: { in: ContactConstants::LANGUAGES }},
        tag_names:  { data_type: { rules: Array }, array: { data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }, string_rejection: { excluded_chars: [','] }},
        time_zone: { custom_inclusion: { in: ContactConstants::TIMEZONES }},
        phone: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        mobile: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        address: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        twitter_id: { length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long }},
        email: { format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, data_type: { rules: String }, length: { maximum: ApiConstants::MAX_LENGTH_STRING, message: :too_long } }
      }

  FIELD_MAPPINGS = { company_name: :company_id, tag_names: :tags, company: :company_id, base: :email, 'primary_email.email'.to_sym => :email }
end

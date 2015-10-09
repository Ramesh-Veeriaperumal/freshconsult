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

  # Based on the Web's behaviour, only jpg and png are allowed to upload
  AVATAR_EXT_REGEX = /.*\.(jpg|png|jpeg)$/i

  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name)

  LANGUAGES = I18n.available_locales.map(&:to_s)

  FIELDS_TO_BE_STRIPPED = %w(address email job_title language name mobile phone time_zone tags twitter_id custom_fields)

  # Wrap parameters args
  WRAP_PARAMS = [:api_contact, exclude: [], format: [:json, :multipart_form]]

  ALLOWED_CONTENT_TYPE_FOR_ACTION = {
    create: [:json, :multipart_form],
    update: [:json, :multipart_form]
  }
end

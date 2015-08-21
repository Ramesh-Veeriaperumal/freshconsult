module ContactConstants
  ARRAY_FIELDS = [{ 'tags' => [String] }]
  CONTACT_FIELDS = %w(address avatar client_manager company_id description email job_title language mobile name phone time_zone twitter_id tags) | ARRAY_FIELDS

  STATES = %w( verified unverified all deleted blocked )

  INDEX_FIELDS = %w( state email phone mobile company_id )

  DELETED_SCOPE = {
    'update' => false,
    'restore' => true,
    'destroy' => false,
    'make_agent' => false
  }

  # Based on limitation specified in Helpdesk::Attachment ( def image? )
  ALLOWED_AVATAR_SIZE = 5 * 1024 * 1024

  MAILER_DAEMON_REGEX = /MAILER-DAEMON@(.+)/i

  # Based on UI only jpg and png are allowed to upload
  AVATAR_EXT_REGEX = /.*\.(jpg|png|jpeg)$/i

  DEMOSITE_URL = AppConfig['demo_site'][Rails.env]

  TIMEZONES = ActiveSupport::TimeZone.all.map(&:name)

  LANGUAGES = I18n.available_locales.map(&:to_s)
end

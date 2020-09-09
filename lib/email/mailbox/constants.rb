module Email::Mailbox::Constants
  BOTH_ACCESS_TYPE = 'both'.freeze
  INCOMING_ACCESS_TYPE = 'incoming'.freeze
  OUTGOING_ACCESS_TYPE = 'outgoing'.freeze
  FRESHDESK_MAILBOX = 'freshdesk_mailbox'.freeze
  CUSTOM_MAILBOX = 'custom_mailbox'.freeze
  MAILBOX_TYPES = [FRESHDESK_MAILBOX, CUSTOM_MAILBOX].freeze
  ACCESS_TYPES = [INCOMING_ACCESS_TYPE, OUTGOING_ACCESS_TYPE, BOTH_ACCESS_TYPE].freeze
  PLAIN = 'plain'.freeze
  LOGIN = 'login'.freeze
  CRAM_MD5 = 'cram_md5'.freeze
  IMAP_CRAM_MD5 = 'cram-md5'.freeze
  OAUTH = 'xoauth2'.freeze
  IMAP_AUTHENTICATION_TYPES = [PLAIN, LOGIN, CRAM_MD5].freeze
  SMTP_AUTHENTICATION_TYPES = [PLAIN, LOGIN].freeze
  OAUTH_TOKEN = 'oauth_token'.freeze
  REFRESH_TOKEN = 'refresh_token'.freeze
  OAUTH_EMAIL = 'oauth_email'.freeze
  IMAP = 'imap'.freeze
  SMTP = 'smtp'.freeze
  IMAP_MAILBOX = 'imap_mailbox'.freeze
  SMTP_MAILBOX = 'smtp_mailbox'.freeze
  OAUTH_SUCCESS = 'success'.freeze
  OAUTH_FAILED = 'failed'.freeze

  GMAIL_OAUTH_URL = "/auth/gmail?origin=id%3D{{account_id}}%26r_key%3D{{r_key}}"
  # Expiry is set to 57 minutes Google currently has an expiry limit of 60 minutes
  ACCESS_TOKEN_EXPIRY = 3420
  GOOGLE_OAUTH2 = 'google_oauth2'.freeze
  AUTH_ERROR = 401
  SMTP_AUTHENTICATION_ERROR_CODE = 535

  TEST_MAIL_VERIFY_DURATION = 30.minutes

  # TODO: should this be part of stack setting
  GMAIL_DEFAULT_REQUESTER = 'forwarding-noreply@google.com'.freeze
  CONFIRMATION_CODE_REGEX = /\(#(\d+)\)/.freeze

  EMAIL_PROVIDER_TIMEOUT = 10.seconds
  EMAIL_SERVICE_PROVIDER_MAPPING = {
    'hotmail' => 'outlook',
    'googlemail' => 'google',
    'yahoodns' => 'yahoo'
  }.freeze

  EMAIL_SERVICE_PROVIDER_OTHER = 'other'.freeze
  EMAIL_SERVICE_PROVIDER_GMAIL = 'google'.freeze
  EMAIL_SERVICE_PROVIDER_OUTLOOK = 'outlook'.freeze

  GMAIL = 'gmail'.freeze
  OFFICE365 = 'office365'.freeze
  SMTP_AUTH_ERROR_CODE = '535'.freeze
  SMTP_TOO_MANY_LOGIN_ATTEMPTS = '454'.freeze

  OUTLOOK_OAUTH_URL = '/auth/outlook?origin=id%3D{{account_id}}%26r_key%3D{{r_key}}'.freeze

  EMAIL_SERVER = [
    ['gmail', 'google_oauth2', 'google_oauth2', 'GMAIL'],
    ['office365', 'outlook', 'outlook', 'O365']
  ].freeze

  APP_NAME_BY_SERVER_KEY = Hash[*EMAIL_SERVER.map { |i| [i[0], i[1]] }.flatten].freeze
  PROVIDER_NAME_BY_SERVER_KEY = Hash[*EMAIL_SERVER.map { |i| [i[0], i[2]] }.flatten].freeze
  IMAP_PROVIDER_NAME_BY_SERVER_KEY = Hash[*EMAIL_SERVER.map { |i| [i[0], i[3]] }.flatten].freeze
end

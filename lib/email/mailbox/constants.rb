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
  IMAP_AUTHENTICATION_TYPES = [PLAIN, LOGIN, CRAM_MD5].freeze
  SMTP_AUTHENTICATION_TYPES = [PLAIN, LOGIN].freeze
end
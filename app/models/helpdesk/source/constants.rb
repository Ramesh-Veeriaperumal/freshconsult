# frozen_string_literal: true

class Helpdesk::Source < Helpdesk::Choice
  EMAIL = 1
  PORTAL = 2
  PHONE = 3
  FORUM = 4
  TWITTER = 5
  FACEBOOK = 6
  CHAT = 7
  MOBIHELP = 8
  FEEDBACK_WIDGET = 9
  OUTBOUND_EMAIL = 10
  ECOMMERCE = 11
  BOT = 12
  WHATSAPP = 13

  DEFAULT_SOURCES = {
    EMAIL => 'Email',
    PORTAL => 'Portal',
    PHONE => 'Phone',
    FORUM => 'Forum',
    TWITTER => 'Twitter',
    FACEBOOK => 'Facebook',
    CHAT => 'Chat',
    MOBIHELP => 'MobiHelp',
    FEEDBACK_WIDGET => 'Feedback Widget',
    OUTBOUND_EMAIL => 'Outbound Email',
    ECOMMERCE => 'Ecommerce',
    BOT => 'Bot',
    WHATSAPP => 'Whatsapp'
  }.freeze

  TICKET_SOURCES = [
    [:email,            'email',            EMAIL],
    [:portal,           'portal_key',       PORTAL],
    [:phone,            'phone',            PHONE],
    [:forum,            'forum_key',        FORUM],
    [:twitter,          'twitter_source',   TWITTER],
    [:facebook,         'facebook_source',  FACEBOOK],
    [:chat,             'chat',             CHAT],
    [:mobihelp,         'mobihelp',         MOBIHELP],
    [:feedback_widget,  'feedback_widget',  FEEDBACK_WIDGET],
    [:outbound_email,   'outbound_email',   OUTBOUND_EMAIL],
    [:ecommerce,        'ecommerce',        ECOMMERCE],
    [:bot,              'bot',              BOT],
    [:whatsapp,         'whatsapp',         WHATSAPP]
  ].freeze

  private_constant :TICKET_SOURCES

  SOURCE_FORMATTER = {
    all_ids: proc { source_from.map(&:account_choice_id) },
    keys_by_token: proc { source_from.map { |choice| [choice.try(:[], :from_constant) ? choice.translated_name : choice.translated_source_name(translation_record_from_ticket_fields), choice.account_choice_id] } },
    token_by_keys: proc { Hash[*source_from.map { |choice| [choice.account_choice_id, choice.default ? SOURCE_TOKENS_BY_KEY[choice.account_choice_id] : choice.name] }.flatten] }
  }.freeze

  private_constant :SOURCE_FORMATTER

  NOTE_SOURCES = %w[email form note status meta twitter feedback facebook forward_email
                    phone mobihelp mobihelp_app_review ecommerce summary canned_form automation_rule automation_rule_forward whatsapp].freeze

  NOTE_EXCLUDE_SOURCES = %w[meta summary].freeze
  MAXIMUM_NUMBER_OF_SOURCES = 1000
  ARCHIVE_NOTE_SOURCES = %w[email form note status meta twitter feedback facebook
                            forward_email phone mobihelp mobihelp_app_review summary automation_rule_forward].freeze

  CUSTOM_SOURCE_MAX_ACTIVE_COUNT = 20
  SOURCE_KEYS_BY_TOKEN = Hash[*TICKET_SOURCES.map { |i| [i[0], i[2]] }.flatten].freeze
  SOURCE_TOKENS_BY_KEY = SOURCE_KEYS_BY_TOKEN.invert.freeze
  SOURCE_NAMES_BY_KEY = Hash[*TICKET_SOURCES.map { |i| [i[2], i[1]] }.flatten].freeze
  API_CREATE_EXCLUDED_VALUES = [SOURCE_KEYS_BY_TOKEN[:forum], SOURCE_KEYS_BY_TOKEN[:outbound_email], SOURCE_KEYS_BY_TOKEN[:bot], SOURCE_KEYS_BY_TOKEN[:whatsapp]].freeze
  API_UPDATE_EXCLUDED_VALUES = [SOURCE_KEYS_BY_TOKEN[:twitter], SOURCE_KEYS_BY_TOKEN[:facebook], SOURCE_KEYS_BY_TOKEN[:whatsapp]].freeze
  CUSTOM_SOURCE_BASE_SOURCE_ID = 100
  CUSTOM_SOURCE_ICON_RANGE = (101..114).to_a.freeze
  DEAFULT_CUSTOM_SOURCE_ICON_ID = 101
end

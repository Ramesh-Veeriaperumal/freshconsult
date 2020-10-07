class Helpdesk::Source < Helpdesk::Choice
  TICKET_SOURCES = [
    [:email,            'email',            1],
    [:portal,           'portal_key',       2],
    [:phone,            'phone',            3],
    [:forum,            'forum_key',        4],
    [:twitter,          'twitter_source',   5],
    [:facebook,         'facebook_source',  6],
    [:chat,             'chat',             7],
    [:mobihelp,         'mobihelp',         8],
    [:feedback_widget,  'feedback_widget',  9],
    [:outbound_email,   'outbound_email',   10],
    [:ecommerce,        'ecommerce',        11],
    [:bot,              'bot',              12],
    [:whatsapp,         'whatsapp',         13]
  ].freeze

  NOTE_SOURCES = ['email', 'form', 'note', 'status', 'meta', 'twitter', 'feedback', 'facebook', 'forward_email',
                  'phone', 'mobihelp', 'mobihelp_app_review', 'ecommerce', 'summary', 'canned_form', 'automation_rule', 'automation_rule_forward', 'whatsapp'].freeze

  NOTE_EXCLUDE_SOURCES = ['meta', 'summary'].freeze
  MAXIMUM_NUMBER_OF_SOURCES = 1000
  ARCHIVE_NOTE_SOURCES = ['email', 'form', 'note', 'status', 'meta', 'twitter', 'feedback', 'facebook',   
               'forward_email', 'phone', 'mobihelp', 'mobihelp_app_review', 'summary', 'automation_rule_forward'].freeze

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

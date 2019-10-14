module ApiConstants
  # ControllerConstants
  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 30,
    max_per_page: 100,
    page: 1
  }.freeze
  ORDER_TYPE = %w(asc desc).freeze

  EMAIL_CONFIG_PER_PAGE = 1000

  # https://github.com/mislav/will_paginate/blob/master/lib/will_paginate/page_number.rb
  PAGE_MAX = WillPaginate::PageNumber::BIGINT

  DEFAULT_PARAMS = %w(version format k id).freeze
  DEFAULT_INDEX_FIELDS = %w(version format k id per_page page).freeze
  PAGINATE_FIELDS = %w(page per_page).freeze
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile

  TIME_UNITS = %w(hours minutes seconds).freeze # do not change the order.

  DEMOSITE_URL = AppConfig['demo_site'][Rails.env]

  # ValidationConstants
  COLOR_CODE_VALIDATOR = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/
  EMAIL_REGEX = AccountConstants::EMAIL_REGEX
  EMAIL_VALIDATOR = AccountConstants::EMAIL_VALIDATOR
  NAMED_EMAIL_VALIDATOR = AccountConstants::NAMED_EMAIL_VALIDATOR
  ALLOWED_ATTACHMENT_SIZE = 15 * 1024 * 1024
  ATTACHMENT_LIMIT = AccountConstants::ATTACHMENT_LIMIT
  LOAD_OBJECT_EXCEPT = [:create, :index, :route_not_found, :filtered_index, :search] +
                       TimeEntryConstants::LOAD_OBJECT_EXCEPT +
                       ConversationConstants::LOAD_OBJECT_EXCEPT +
                       DiscussionConstants::LOAD_OBJECT_EXCEPT +
                       SolutionConstants::LOAD_OBJECT_EXCEPT +
                       SurveyConstants::LOAD_OBJECT_EXCEPT +
                       ContactConstants::LOAD_OBJECT_EXCEPT +
                       CompanyConstants::LOAD_OBJECT_EXCEPT +
                       ApiTicketConstants::LOAD_OBJECT_EXCEPT +
                       DraftConstants::LOAD_OBJECT_EXCEPT +
                       SubscriptionConstants::LOAD_OBJECT_EXCEPT +
                       SpotlightConstants::LOAD_OBJECT_EXCEPT +
                       ApiSearch::AutocompleteConstants::LOAD_OBJECT_EXCEPT +
                       AttachmentConstants::LOAD_OBJECT_EXCEPT +
                       ApiLeaderboardConstants::LOAD_OBJECT_EXCEPT +
                       Pipe::HelpdeskConstants::LOAD_OBJECT_EXCEPT +
                       ExportConstants::LOAD_OBJECT_EXCEPT +
                       Freshcaller::SearchConstants::LOAD_OBJECT_EXCEPT +
                       Freshcaller::SettingsConstants::LOAD_OBJECT_EXCEPT +
                       DashboardConstants::LOAD_OBJECT_EXCEPT +
                       AgentConstants::LOAD_OBJECT_EXCEPT +
                       IntegratedUserConstants::LOAD_OBJECT_EXCEPT +
                       BotConstants::LOAD_OBJECT_EXCEPT +
                       ApiArchiveTicketConstants::LOAD_OBJECT_EXCEPT +
                       BotFeedbackConstants::LOAD_OBJECT_EXCEPT +
                       RakeTaskConstants::LOAD_OBJECT_EXCEPT +
                       FreshmarketerConstants::LOAD_OBJECT_EXCEPT +
                       AuditLogConstants::LOAD_OBJECT_EXCEPT +
                       AdminSubscriptionConstants::LOAD_OBJECT_EXCEPT +
                       AdvancedTicketingConstants::LOAD_OBJECT_EXCEPT +
                       CannedResponseConstants::LOAD_OBJECT_EXCEPT +
                       AuditLogConstants::LOAD_OBJECT_EXCEPT +
                       Solutions::HomeConstants::LOAD_OBJECT_EXCEPT +
                       Testing::FreshidApiConstants::LOAD_OBJECT_EXCEPT +
                       Admin::CustomTranslationsConstants::LOAD_OBJECT_EXCEPT

  NO_CONTENT_TYPE_REQUIRED = ApiTicketConstants::NO_CONTENT_TYPE_REQUIRED +
                             ContactConstants::NO_CONTENT_TYPE_REQUIRED +
                             SubscriptionConstants::NO_CONTENT_TYPE_REQUIRED +
                             TimeEntryConstants::NO_CONTENT_TYPE_REQUIRED +
                             CustomerImportConstants::NO_CONTENT_TYPE_REQUIRED +
                             Freddy::Util::NO_CONTENT_TYPE_REQUIRED

  ALLOWED_DOMAIN = AppConfig['base_domain'][Rails.env]
  MAX_LENGTH_STRING = 255
  MAX_ITEMS_FOR_BULK_ACTION = 100

  TAG_MAX_LENGTH_STRING = 32
  CACHE_VERSION = { v2: 'V2', v3: 'V3' }.freeze

  PRIVILEGES_WITH_OWNEDBY = ABILITIES.values.flatten.select(&:owned_by).map(&:name).uniq

  # Wrap parameters args
  WRAP_PARAMS = [exclude: [], format: :json].freeze

  UTC = 'UTC'.freeze

  URL_REGEX = /^($)|^(https?|s?ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i

  VALUE_NOT_DEFINED = :value_not_defined

  ALPHABETS = ('A'..'Z').to_a.freeze

  BULK_ACTION_ARRAY_FIELDS = ['ids'].freeze
  BULK_ACTION_FIELDS = BULK_ACTION_ARRAY_FIELDS.freeze
  BULK_ACTION_METHODS = ApiTicketConstants::BULK_ACTION_METHODS +
                        ContactConstants::BULK_ACTION_METHODS +
                        CompanyConstants::BULK_ACTION_METHODS +
                        SubscriptionConstants::BULK_ACTION_METHODS +
                        BotFeedbackConstants::BULK_ACTION_METHODS
  BULK_ACTION_ASYNC_METHODS = ApiTicketConstants::BULK_ACTION_ASYNC_METHODS

  TWITTER_REPLY_TYPES = %w(mention dm).freeze
  TWEET_MAX_LENGTH = 280
  TWITTER_DM_MAX_LENGTH = 10000
  MAX_CUSTOMER_EXPORT_FIELDS = 100

  APP_AUTHORIZATION_WHITELIST = { 'ember/freshconnect' => [:update] }.freeze

  TWITTER_ALLOWED_ATTACHMENT_TYPES = {
    'image/jpeg' => 'image',
    'image/png' => 'image',
    'image/jpg' => 'image'
  }.freeze

  TWITTER_ATTACHMENT_CONFIG = {
    dm: {
      fileTypes: ['image'],
      image: { size: 3, limit: 1 },
      gif: { size: 15, limit: 1 }
    },
    mention: {
      fileTypes: ['image'],
      image: { size: 5, limit: 4 },
      gif: { size: 15, limit: 1 }
    }
  }.freeze

  FACEBOOK_ATTACHMENT_CONFIG = {
    post: {
      fileTypes: ['image/jpeg', 'image/png', 'image/jpg', 'image/gif', 'image/tiff'],
      size: 20
    }
  }.freeze

end.freeze

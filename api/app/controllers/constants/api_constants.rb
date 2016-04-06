module ApiConstants
  # ControllerConstants
  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 30,
    max_per_page: 100,
    page: 1
  }

  # https://github.com/mislav/will_paginate/blob/master/lib/will_paginate/page_number.rb
  PAGE_MAX = WillPaginate::PageNumber::BIGINT

  DEFAULT_PARAMS = %w(version format k id).freeze
  DEFAULT_INDEX_FIELDS = %w(version format k id per_page page).freeze
  PAGINATE_FIELDS = %w(page per_page).freeze
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile

  TIME_UNITS = %w(hours minutes seconds).freeze # do not change the order.

  DEMOSITE_URL = AppConfig['demo_site'][Rails.env]

  # ValidationConstants
  EMAIL_REGEX = AccountConstants::EMAIL_REGEX
  EMAIL_VALIDATOR = AccountConstants::EMAIL_VALIDATOR
  ALLOWED_ATTACHMENT_SIZE = 15 * 1024 * 1024

  LOAD_OBJECT_EXCEPT = [:create, :index, :route_not_found, :filtered_index, :search] +
                       TimeEntryConstants::LOAD_OBJECT_EXCEPT +
                       ConversationConstants::LOAD_OBJECT_EXCEPT +
                       DiscussionConstants::LOAD_OBJECT_EXCEPT

  ALLOWED_DOMAIN = AppConfig['base_domain'][Rails.env]
  MAX_LENGTH_STRING = 255

  TAG_MAX_LENGTH_STRING = 32
  CACHE_VERSION = { v2: 'V2', v3: 'V3' }.freeze

  PRIVILEGES_WITH_OWNEDBY = ABILITIES.values.flatten.select(&:owned_by).map(&:name).uniq

  # Wrap parameters args
  WRAP_PARAMS = [exclude: [], format: :json].freeze

  UTC = 'UTC'.freeze

  URL_REGEX = /^(https?|s?ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i
end.freeze

module Admin::ShiftConstants
  REQUEST_PERMITTED_PARAMS = %i[name time_zone work_days agents].freeze

  PRODUCT = 'freshdesk'.freeze

  ACTION_METHOD_TO_CLASS_MAPPING = { index: Net::HTTP::Get, show: Net::HTTP::Get, update: Net::HTTP::Put,
                                     create: Net::HTTP::Post, destroy: Net::HTTP::Delete, patch: Net::HTTP::Patch,
                                     fetch_availability: Net::HTTP::Get, update_availability: Net::HTTP::Patch }.freeze

  SUCCESS_CODES = 200..299.freeze

  PAGE_PARAMS = %i[page per_page].freeze

  SHIFT_INDEX = 'api/v1/shifts/'.freeze

  SHIFT_SHOW = 'api/v1/shifts/%{shift_id}'.freeze

  AGENT_STATUS_URL = 'api/v1/agents/%{id}/mark-unavailable'.freeze

  TIMEOUT = ShiftConfig['time_out']

  AVAILABILITY = 'availability'.freeze
end

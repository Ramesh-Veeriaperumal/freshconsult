module Silkroad
  module Constants
    module Base
      FRESHDESK_PRODUCT = 'freshdesk'.freeze
      CREATE_JOB_URL = "#{SILKROAD_CONFIG[:host]}/api/v1/jobs/".freeze
      GET_JOB_URL = "#{SILKROAD_CONFIG[:host]}/api/v1/jobs/%{job_id}".freeze
      OPERATORS = {
        equal: 'eq',
        not_equal: 'ne',
        in: 'in',
        greater_than: 'gt',
        greater_than_or_equal_to: 'ge',
        less_than: 'lt',
        less_than_or_equal_to: 'le',
        between: 'between',
        nested_or: 'nested_or'
      }.freeze
      CONTENT_TYPE = 'application/json'.freeze
    end
  end
end

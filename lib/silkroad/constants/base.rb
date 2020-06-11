module Silkroad
  module Constants
    module Base
      FRESHDESK_PRODUCT = 'freshdesk'.freeze
      CREATE_JOB_URL = "#{SILKROAD_CONFIG['host']}/api/v1/jobs/".freeze
      GET_JOB_URL = "#{SILKROAD_CONFIG['host']}/api/v1/jobs/%{job_id}".freeze
      FILTER_CONDITION_KEYS = [:column_name, :operator, :operand].freeze
      CALLBACK_URL = 'https://%{account_domain}/api/channel/admin/data_export/update'.freeze
      OPERATORS = {
        equal: 'eq',
        not_equal: 'ne',
        in: 'in',
        greater_than: 'gt',
        greater_than_or_equal_to: 'ge',
        less_than: 'lt',
        less_than_or_equal_to: 'le',
        between: 'between'
      }.freeze
    end
  end
end

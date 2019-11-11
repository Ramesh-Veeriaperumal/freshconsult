module Freddy
  module Constants
    SERVICE = 'freshdesk'.freeze

    SYSTEM42_HOST = FreddySkillsConfig[:system42][:host]

    FLOWSERV_HOST = FreddySkillsConfig[:flowserv][:host]

    NO_CONTENT_TYPE_REQUIRED = [:execute].freeze

    UPLOAD_FILE = 'uploadFile'.freeze

    SYSTEM42_NAMESPACE = '/api/v1/'.freeze

    BOTFLOW_URL = 'botflow/'.freeze

    ATTACHMENTS = 'attachments'.freeze
  end
end

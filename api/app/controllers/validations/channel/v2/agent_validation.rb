module Channel::V2
  class AgentValidation < ::AgentValidation
    attr_accessor :sync_meta
    validates :sync_meta, presence: true, on: :sync
  end
end

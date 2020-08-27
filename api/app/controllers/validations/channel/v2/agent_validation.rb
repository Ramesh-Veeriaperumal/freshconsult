module Channel::V2
  class AgentValidation < ::AgentValidation
    attr_accessor :meta
    validates :meta, presence: true, on: :sync
  end
end

class GroupDecorator
  class << self
    def round_robin_enabled?
      Account.current.features? :round_robin
    end
  end
end

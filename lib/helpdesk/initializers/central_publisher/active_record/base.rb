module ActiveRecord
  class Base
    def self.disallow_payload?(payload_type)
      Account.current.subscription.suspended?
    end
  end
end

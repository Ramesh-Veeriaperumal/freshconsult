class Account < ActiveRecord::Base
  class RecordNotFound < StandardError
  end

  class << self
    def find(*args)
      super(*args)
    rescue ActiveRecord::RecordNotFound => e
      raise RecordNotFound, e.message
    end
  end
end

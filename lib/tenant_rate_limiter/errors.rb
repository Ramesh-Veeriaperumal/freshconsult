# frozen_string_literal: true

module TenantRateLimiter
  module Errors
    class InvalidTenant < StandardError
    end

    class InvalidIterableType < StandardError
    end

    class JobFailure < StandardError
    end
  end
end

module SchedulerService
  module Errors

    class BadRequestException < StandardError
    end

    class GatewayTimeoutException < StandardError
    end

  end
end
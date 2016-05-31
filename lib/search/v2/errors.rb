module Search
  module V2
    module Errors

      class ServerNotUpException < StandardError
      end
      
      class RequestTimedOutException < StandardError
      end

      class BadRequestException < StandardError
      end

      class IndexRejectedException < StandardError
      end

      class DefaultSearchException < StandardError
      end

    end
  end
end
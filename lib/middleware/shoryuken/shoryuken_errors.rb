module Middleware
  module Shoryuken
    module ShoryukenErrors
      class InvalidCurrentUserException < StandardError; end
      class InvalidCurrentAccountException < StandardError; end
    end
  end
end
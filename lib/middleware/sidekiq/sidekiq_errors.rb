module Middleware
  module Sidekiq
    module SidekiqErrors
      class InvalidCurrentUserException < StandardError; end
      class InvalidCurrentAccountException < StandardError; end
    end
  end
end
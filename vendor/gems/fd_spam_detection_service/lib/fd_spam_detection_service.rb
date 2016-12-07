require "fd_spam_detection_service/service"
require "fd_spam_detection_service/result"
require "fd_spam_detection_service/config"
module FdSpamDetectionService
  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end
end
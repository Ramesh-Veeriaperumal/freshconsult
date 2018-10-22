module Sync
  module Logger
    def self.sync_log_file
      "#{Rails.root}/log/sync.log"
    end

    def self.logger
      @@sync_logger ||= ::Logger.new(sync_log_file)
    end

    def self.log text
      log_text = text
      log_text = "\n #{Thread.current[:message_uuid].inspect} #{Time.now} #{text}"
      logger.info log_text
    rescue => e
      p e
      p e.backtrace
      Rails.logger.debug log_text
      NewRelic::Agent.notice_error(e, {
          :custom_params => {
            :description => "Error in writing to sbrr.log, #{e.message}",
        }})
    end
  end
end

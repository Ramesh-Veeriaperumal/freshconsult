class HelpkitFeedsLogger

  class << self

    def log(acc_id, uuid, exchange, message, key)
      # Added in this format so that we can index in sumologic
      message = "account_id=#{acc_id}, exchange=#{exchange}, routing_key=#{key}, payload=#{message}"
      log_device.debug("[#{uuid}] #{message}")
    rescue Exception => e
      Rails.logger.error("[#{uuid}] Exception in helpkit feeds Logger :: #{e.message}")
      NewRelic::Agent.notice_error(e)
    end

    private

      def log_path
        @@helpkit_feedslog ||= "#{Rails.root}/log/helpkit_feeds.log"
      end 

      def log_device
        @@helpkit_feeds_logger ||= Logger.new(log_path)
      end
  end
end
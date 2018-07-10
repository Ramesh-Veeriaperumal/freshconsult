module Sync
  module CustomLogger
    def sync_log_file
      "#{Rails.root}/log/sync.log"
    end

    def sync_logger
      @sync_logger ||= Logger.new(sync_log_file)
    end
  end
end

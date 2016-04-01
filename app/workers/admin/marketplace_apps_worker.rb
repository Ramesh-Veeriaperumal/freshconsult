module Admin
  class MarketplaceAppsWorker < ::BaseWorker
    include ::Marketplace::ApiMethods

    RETRY_COUNT = 10

    sidekiq_options :queue => :marketplace_apps, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args)
      begin
        args.symbolize_keys!
        result = ni_latest_details(args[:name])
        if error_status?(result)
          enqueue_later(args)
          return
        end
        params = result.body.symbolize_keys
        params = params.merge({ 
                  :configs => args[:configs], 
                  :type => ::Marketplace::Constants::EXTENSION_TYPE[:ni],
                  :enabled => ::Marketplace::Constants::EXTENSION_STATUS[:enabled]
                 }) if ['install', 'update'].include?(args[:method])
        ext_result = send("#{args[:method]}_extension", params)
        if error_status?(ext_result)
          enqueue_later(args)
          return
        end
      rescue => e
        Rails.logger.error("\n#{e.message}\n#{e.backtrace.join("\n")}")
        NewRelic::Agent.notice_error(e, {:description => "Exception occured while calling marketplace api"})
        enqueue_later(args)
      end
    end

    private

    def enqueue_later(args)
      args[:retry_count] = args[:retry_count].to_i  + 1
      return if args[:retry_count] > RETRY_COUNT
      args[:retry_after] = 5.minutes.from_now
      self.class.perform_async(args)
    end
  end
end
module Integrations
  class MarketplaceAppBillingWorker < ::BaseWorker
    include Redis::RedisKeys
    include Redis::OthersRedis
    include Sidekiq::Worker
    include ::Marketplace::ApiMethods
    include ::MarketplaceAppHelper
    include ::Marketplace::GalleryConstants

    sidekiq_options queue: :marketplace_app_billing, retry: 10, backtrace: true, failures: :exhausted

    sidekiq_retry_in { 15 }

    sidekiq_retries_exhausted do |message, error|
      Rails.logger.error("Failed #{message['class']} with #{message['args']}: #{message['error_message']}, will be deleted")
      delete_billing_failed_app(message['args'].first)
    end

    def perform(args)
      response = verify_app_billing_status(args)
      raise StandardError unless completed?(response)

      delete_billing_failed_app(args) if should_delete?(response)
    end

    private

      def verify_app_billing_status(args)
        ni_addon_detail = marketplace_ni_extension_details(Account.current.id, args['app_name'])
        fetch_app_status(ni_addon_detail['installed_extension_id'])
      end

      def completed?(response)
        response && response.status == COMPLETION_STATUS
      end

      def should_delete?(response)
        response && response.status == COMPLETION_STATUS && response.body['status'] == BILLING_FAILED
      end

      def delete_billing_failed_app(args)
        installed_app = Account.current.installed_applications.with_name(args['app_name']).first
        if installed_app.present?
          installed_app.skip_makrketplace_syncup = true
          installed_app.destroy
        end
      end
  end
end

module Social
  class GatewayFacebookWorker < BaseWorker
    include Sidekiq::Worker
    include Admin::Social::FacebookGatewayHelper

    sidekiq_options queue: :gateway_facebook_page, retry: 3, backtrace: true, failures: :exhausted

    sidekiq_retry_in { 30 }

    RETRY_STATUSES = [500, 502, 504].freeze
    ACTION_METHOD_MAP = {
      'create' => 'put',
      'destroy' => 'delete',
      'update' => 'update'
    }.freeze

    def perform(args)
      make_cud_gateway_facebook_request(args) if ACTION_METHOD_MAP.key?(args['action'])
    end

    private

      def make_cud_gateway_facebook_request(args)
        case args['action']
        when 'create'
          subscribe_realtime_with_gateway_validation(args['page_id'])
          create_or_remove_gateway_facebook_record(args)
        when 'destroy'
          create_or_remove_gateway_facebook_record(args)
        # Below needs to be executed when page-token is updated, we need to resubscribe with FB using the new token
        # Gateway Details doesn't need to be modified.
        when 'update'
          subscribe_realtime(args['page_id'])
        end
      end

      def create_or_remove_gateway_facebook_record(args)
        page_id = args['page_id']
        response = HttpRequestProxy.new.fetch_using_req_params(build_gateway_param_with_body(page_id), build_request_params(ACTION_METHOD_MAP[args['action']]), create_payload_option)
        raise 'GatewayRequestError' if RETRY_STATUSES.include?(response[:status])
      rescue StandardError => e
        SocialErrorsMailer.deliver_facebook_exception(e, page_id: page_id, account_id: Account.current.id) unless Rails.env.test?
        Rails.logger.error("An Exception occured while performing Gateway operation for #{args['action']}, \n
          facebookPage::#{page_id}, account::#{Account.current.id}, message::#{e.message}")
        NewRelic::Agent.notice_error(e, description: "An Exception occured while performing Gateway operation for #{args['action']} \n
          facebookPage::#{page_id}, account::#{Account.current.id}, message::#{e.message}}")
      end

      def subscribe_realtime_with_gateway_validation(page_id)
        gateway_fb_accounts_count, = gateway_facebook_page_mapping_details(page_id)
        return if gateway_fb_accounts_count > 0

        subscribe_realtime(page_id)
      end

      def subscribe_realtime(page_id)
        page = Account.current.facebook_pages.find_by_page_id(page_id)
        Facebook::PageTab::Configure.new(page).execute('subscribe_realtime') if page.enable_page && page.company_or_visitor?
      end
  end
end

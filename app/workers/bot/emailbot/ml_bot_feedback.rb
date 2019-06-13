module Bot::Emailbot
  class MlBotFeedback < BaseWorker
    sidekiq_options queue: :bot_email_ml_feedback, retry: 0,  failures: :exhausted
    FEEDBACK_CONFIG = YAML.load(ERB.new(File.read("#{Rails.root}/config/email_bot_ml_feedback_config.yml")).result)[Rails.env]
    PAYLOAD_TYPE = "freshdesk-email-bot-feedback"
    TYPE = "FEEDBACK"

    def perform(args)
      begin
        args.symbolize_keys!
        @bot_response = Account.current.bot_responses.find(args[:bot_response_id])
        payload = construct_central_payload(args[:article_meta_id])
        send_feedback(payload)
      rescue => e
        NewRelic::Agent.notice_error(e)
        Rails.logger.error("ML Solutions Training Failure :: Account id : #{Account.current.id} :: BotResponse ID : #{@bot_response.id} :: Article_meta : #{args[:article_meta_id]} \n#{e.message}")
      end
    end

    private

      def send_feedback payload
        response = create_connection.post { |r| r.body = request_body(payload) }
        if response.status == 202
          Rails.logger.info("Feedback for bot response successfully sent to central :: Account id : #{Account.current.id} :: bot_response id : #{@bot_response.id}")
        else
          raise "Central publish failed with response code : #{response.status} :: Response : #{response.inspect}"
        end
      end

      def create_connection
        @connection ||= Faraday.new(:url => FEEDBACK_CONFIG['api_endpoint']) do |conn|
          conn.request :json
          conn.adapter Faraday.default_adapter
        end
        @connection.headers = {
          'service' => FEEDBACK_CONFIG['service_token'],
          'pod' => PodConfig['CURRENT_POD'],
          'region' => PodConfig['CURRENT_REGION']
        }
        @connection
      end

      def request_body payload
        {
          account_id: Account.current.id.to_s,
          payload_type: PAYLOAD_TYPE,
          payload: payload
        }.to_json
      end

      def construct_central_payload article_meta_id
        {
          queryId: @bot_response.query_id,
          ticketId: @bot_response.ticket_id,
          queryDate: @bot_response.created_at.to_i,
          portal_id: @bot_response.bot.portal_id.to_s,
          type: TYPE,
          productId: BOT_CONFIG[:freshdesk_product_id],
          domainName: @bot_response.bot.portal.host,
          query: @bot_response.ticket.ticket_body.description,
          faqs: construct_faqs(article_meta_id)
        }
      end

      def construct_faqs article_meta_id
        @bot_response.suggested_articles.each.map do |article_id, suggested_hash|
          {
            text: suggested_hash[:title],
            articleId: article_id,
            useful: suggested_hash[:useful],
            agent_useful: suggested_hash[:agent_feedback]
          }
        end
      end
  end
end

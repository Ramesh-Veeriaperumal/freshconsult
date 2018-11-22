module Freshbots
  class Bot
    BOT_CREATION_SUCCESS_STATUS = 201
    BOT_UPDATION_SUCCESS_STATUS = 200
    INTERNAL_NAME = 'FrankBot'.freeze

    class << self
      def create_bot(bot)
        current_user = User.current
        url = BOT_CONFIG[:create_bot_url]
        headers = build_headers(bot, :create)
        payload = {
          nm: bot.name,
          intrnlNm: INTERNAL_NAME,
          prflPicUrl: profile_picture_url(bot),
          tmpltHsh: BOT_CONFIG[:template_hash],
          chngdByUsr: current_user.name,
          wdgtHdrPrprts: {
            subTtl: bot.template_data[:header]
          },
          clnt: {
            clntId: bot.external_id,
            dmn: bot.external_id, # Domain needs to be unique and freshbots will create an account on their end : freshdesk-#{dmn}.intfreshbots.com
            eml: current_user.email,
            mtdtPrprts: {
              bckgrndClr: bot.template_data[:theme_colour],
              sz: bot.template_data[:widget_size],
              prtl: portal_url(bot),
              acntUrl: account_url(bot)
            }
          }
        }.to_json
        response = RestClient.post url, payload, headers
        response_code = response.code
        response = JSON.parse(response.body)
        [response, response_code]
      end

      def update_bot(bot)
        current_user = User.current
        url = BOT_CONFIG[:update_bot_url] % { botHash: bot.additional_settings[:bot_hash].to_s }
        headers = build_headers(bot, :update)
        payload = {
          nm: bot.name,
          prflPicUrl: profile_picture_url(bot),
          intrnlNm: INTERNAL_NAME,
          chngdByUsr: current_user.name,
          wdgtHdrPrprts: {
            subTtl: bot.template_data[:header]
          },
          clnt: {
            mtdtPrprts: {
              bckgrndClr: bot.template_data[:theme_colour],
              sz: bot.template_data[:widget_size],
              prtl: portal_url(bot),
              acntUrl: account_url(bot)
            }
          }
        }.to_json
        response = RestClient.put url, payload, headers
        [response, response.code]
      end

      def analytics(bot_external_id, start_date, end_date)
        begin
          url = BOT_CONFIG[:analytics_url]
          response = RestClient.get url, analytics_headers(bot_external_id, start_date, end_date)
        rescue => e
          return [e.response, e.response.code.to_i]
        end
        [response, response.code]
      end

      def chat_messages(bot_feedback, direction = BotFeedbackConstants::CHAT_HISTORY_DIRECTIONS[0], incld_msg = true, query_id = nil)
        url = Addressable::URI.parse(BOT_CONFIG[:chat_history_url].gsub('custHash',bot_feedback.external_info[:customer_id]))
        url.query_values = construct_query_params(bot_feedback, direction, incld_msg, query_id)
        headers = { 'Client-Id': bot_feedback.external_info[:client_id] }
        response = RestClient.get url.to_s, headers
        raise "ChatHistoryApiException: Response: #{response}, Response Code: #{response.code}" if response.nil? || response.code != 200
        response = JSON.parse(response)['data']
        [response,response.count < BotFeedbackConstants::CHAT_HISTORY_MSG_COUNT]
      end

      private

        def external_client_id(bot, action)
          # When creating a bot, the master_client_external_id used is a default
          # bot which acts as a template for creating a new bot.
          if action == :create
            BOT_CONFIG[:master_client_external_id]
          else
            bot.external_id
          end
        end

        def build_headers(bot, action)
          {
            'Accept' => '*/*',
            'Product-Id' => (BOT_CONFIG[:freshdesk_product_id]).to_s,
            'fbots-service' => (BOT_CONFIG[:fbots_service]).to_s,
            'External-Client-Id' => external_client_id(bot, action),
            'Content-Type' => 'application/json'
          }
        end

        def analytics_headers(bot_external_id, start_date, end_date)
          {
            'Product-Id' => (BOT_CONFIG[:freshdesk_product_id]).to_s,
            'External-Client-Id' => bot_external_id,
            'Params' => { strtDt: start_date, endDt: end_date }
          }
        end

        def profile_picture_url(bot)
          if bot.additional_settings[:is_default]
            bot.additional_settings[:default_avatar_url]
          else
            bot.thumbnail_cdn_url
          end
        end

        def portal_url(bot)
          portal = bot.portal
          "#{portal.url_protocol}://#{portal.host}"
        end

        def account_url(bot)
          "https://#{bot.account.full_domain}"
        end

        def construct_query_params(bot_feedback, direction, incld_msg, query_id)
          query_hash = {
            ordrBy: BotFeedbackConstants::CHAT_HISTORY_DIRECTION_VALUES[direction],
            tcktMsgHsh: query_id || bot_feedback.query_id,
            cntMsgTRtrv: BotFeedbackConstants::CHAT_HISTORY_MSG_COUNT,
            incldPssdMssg: incld_msg
          }
          query_hash[:msgDrctn] = BotFeedbackConstants::CHAT_HISTORY_DIRECTIONS[0] if direction == BotFeedbackConstants::CHAT_HISTORY_DIRECTIONS[0]
          query_hash
        end
    end
  end
end

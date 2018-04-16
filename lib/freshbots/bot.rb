module Freshbots
  class Bot
    BOT_CREATION_SUCCESS_STATUS = 201
    BOT_UPDATION_SUCCESS_STATUS = 200
    INTERNAL_NAME = 'FrankBot'.freeze
    MASTER_CLIENT_EXTERNAL_ID = 'freshdesk-frankbot-us'.freeze

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
              prtl: portal_url(bot)
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
              prtl: portal_url(bot)
            }
          }
        }.to_json
        response = RestClient.put url, payload, headers
        [response, response.code]
      end

      private

        def external_client_id(bot, action)
          # When creating a bot, the MASTER_CLIENT_EXTERNAL_ID used is a default
          # bot which acts as a template for creating a new bot.
          if action == :create
            MASTER_CLIENT_EXTERNAL_ID
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

        def profile_picture_url(bot)
          if bot.additional_settings[:is_default]
            bot.additional_settings[:default_avatar_url]
          else
            bot.cdn_url
          end
        end

        def portal_url(bot)
          portal = bot.portal
          "#{portal.url_protocol}://#{portal.host}"
        end
    end
  end
end

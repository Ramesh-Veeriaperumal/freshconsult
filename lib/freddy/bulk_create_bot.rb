module Freddy
  module BulkCreateBot
    include Freshchat::Util
    FRESHDESK_SERVICE = 'freshdesk'.freeze
    SUCCESS = 200
    FRESHCHAT_SUCCESS_STATUS_CODES = [201, 200].freeze
    BOT_ATTRIBUTES = ['cortex_id', 'name', 'status', 'widget_config', 'portal_id'].freeze

    def bulk_create_bot_perform(args)
      @proxy_response = {}
      args.symbolize_keys!
      @current_account = Account.current
      @action = args[:action]
      if @action == :autofaq
        @proxy_response = enable_freshchat
        return unless FRESHCHAT_SUCCESS_STATUS_CODES.include?(@proxy_response.code)
      end

      time_taken = Benchmark.realtime { @proxy_response = HTTParty.put(FreddySkillsConfig[:system42][:onboard_url], bulk_create_bot_options) }
      Rails.logger.info "Time Taken for bulk_create_bot - #{@current_account.id} time - #{time_taken}"
      parsed_response = @proxy_response.parsed_response
      create_freddy_bot(parsed_response) if (parsed_response.is_a? Hash) && (@proxy_response.code == SUCCESS)
    rescue StandardError => e
      FreddyLogger.log "Error in BulkCreateBotWorker::Exception:: #{e.message}"
      options_hash = { custom_params: { description: "Error in BulkCreateBotWorker::Exception:: #{e.message}", account_id: Account.current.id, job_id: Thread.current[:message_uuid].to_s } }
      NewRelic::Agent.notice_error(e, options_hash)
    end

    private

      def enable_freshchat
        if @current_account.freshchat_account
          freshchat_account = @current_account.freshchat_account
          freshchat_account.enabled = true
          sync_freshchat(freshchat_account.app_id) if freshchat_account.save
        else
          freshchat_signup
        end
      end

      def create_freddy_bot(response)
        bots = response['bots']
        bots.each do |bot|
          freddy_bot = @current_account.freddy_bots.new(sanitize_bot_params(bot))
          freddy_bot.save
        end
      end

      def sanitize_bot_params(bot)
        bot['portal_id'] = bot['group_id']
        bot['status'] = bot['status'] == 'ENABLE'
        bot.slice(*BOT_ATTRIBUTES)
      end

      def bulk_create_bot_options
        {
          headers: bulk_create_bot_headers,
          body: { bots: construct_bot }.to_json,
          timeout: FreddySkillsConfig[:system42][:timeout]
        }
      end

      def construct_bot
        portals = @current_account.portals
        account_system42_features = system42_features
        portals.map do |portal|
          {
            name: portal.name,
            account_id: portal.account_id,
            domain: @current_account.full_domain,
            group_id: portal.id,
            enabled_features: account_system42_features,
            freshchat: construct_freshchat_params,
            supported_languages: @current_account.portal_languages,
            primary_language: @current_account.language,
            user_id: User.current.id,
            status: 'DISABLE',
            bundle_id: @current_account.omni_bundle_id,
            bundle_name: @current_account.omni_bundle_name
          }
        end
      end

      def system42_features
        system42_features = []
        system42_features << :autofaq if @current_account.autofaq_enabled?
        system42_features << :agent_articles_suggest if @current_account.agent_articles_suggest_enabled?
        system42_features << :email_articles_suggest if @current_account.email_articles_suggest_enabled?
        system42_features
      end

      def construct_freshchat_params
        if @current_account.autofaq_enabled? && @current_account.freshchat_account
          {
            app_id: @current_account.freshchat_account.app_id,
            widget_token: @current_account.freshchat_account.token
          }
        end
      end

      def bulk_create_bot_headers
        jwt_token = bulk_create_bot_jwt_token
        {
          'Authorization' => "Bearer #{jwt_token}",
          'Content-Type' => 'application/json',
          'X-Request-ID' => Thread.current[:message_uuid].to_s
        }
      end

      def bulk_create_bot_jwt_token
        JWT.encode bulk_create_bot_payload, FreddySkillsConfig[:system42][:secret], 'HS256', { 'alg': 'HS256', 'typ': 'JWT' }
      end

      def bulk_create_bot_payload
        {}.tap do |claims|
          claims[:aud] = @current_account.id.to_s
          claims[:exp] = Time.zone.now.to_i + 10.minutes
          claims[:iat] = Time.zone.now.to_i
          claims[:iss] = FRESHDESK_SERVICE
        end
      end
  end
end

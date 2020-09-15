module Ml
  class Bot
    class << self
      include ::Freddy::Constants
      include ::Freddy::Util

      CONTENT_TYPE = 'application/json'.freeze
      ONBOARD_NAMESPACE = '/api/v1/onboarding/onboard-freshdesk-accounts'.freeze
      MAP_CATEGORIES_NAMESPACE = '/api/v1/map_categories'.freeze

      def update_ml(bot)
        url = FreddySkillsConfig[:system42][:host] + MAP_CATEGORIES_NAMESPACE
        body = { category_ids: bot.solution_category_metum_ids }.to_json
        time_taken = Benchmark.realtime { @proxy_response = HTTParty.put(url, options(CONTENT_TYPE, body, :system42, bot.portal_id.to_s)) }
        Rails.logger.info "Time Taken for map_categories - #{@proxy_response} #{bot.account_id} time - #{time_taken}"
        response = @proxy_response.parsed_response
        response['success'] if (response.is_a? Hash) && (@proxy_response.code == 200)
      rescue StandardError => e
        FreddyLogger.log "Error while processing #{bot.account_id} #{url} serv request:: #{e.message} :: #{e.backtrace[0..10].inspect}"
        NewRelic::Agent.notice_error(e)
      end

      def onboard_system42(bot)
        url = FreddySkillsConfig[:system42][:host] + ONBOARD_NAMESPACE
        time_taken = Benchmark.realtime { @proxy_response = HTTParty.post(url, options(CONTENT_TYPE, onboard_system42_body(bot), :system42, bot.portal_id.to_s)) }
        Rails.logger.info "Time Taken for onboard_system42 url=#{url} account_id=#{bot.account_id}, portal_id=#{bot.portal_id}, response=#{@proxy_response.inspect}, time - #{time_taken}"
      rescue StandardError => e
        Rails.logger.error "Error while processing system42 onboard #{bot.account_id} #{bot.portal_id} #{url} serv request:: #{e.message} :: #{e.backtrace[0..10].inspect}"
        NewRelic::Agent.notice_error(e)
      end

      private

        def onboard_system42_body(bot)
          [{
            domain: Account.current.full_domain,
            bot_id: bot.external_id,
            portal_id: bot.portal_id,
            account_id: bot.account_id
          }].to_json
        end
    end
  end
end

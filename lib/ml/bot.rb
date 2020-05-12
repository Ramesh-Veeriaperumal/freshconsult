module Ml
  class Bot
    class << self
      include ::Freddy::Constants
      include ::Freddy::Util
      def update_ml(bot)
        begin
          url = FreddySkillsConfig[:system42][:host] + '/api/v1/map_categories'
          body = { category_ids: bot.solution_category_metum_ids }.to_json
          time_taken = Benchmark.realtime { @proxy_response = HTTParty.put(url, options('application/json', body, :system42, bot.portal_id.to_s)) }
          Rails.logger.info "Time Taken for map_categories - #{@proxy_response} #{bot.account_id} time - #{time_taken}"
          response = @proxy_response.parsed_response
          response['success'] if (response.is_a? Hash) && (@proxy_response.code == 200)
        rescue StandardError => e
          FreddyLogger.log "Error while processing #{bot.account_id} #{url} serv request:: #{e.message} :: #{e.backtrace[0..10].inspect}"
          NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end

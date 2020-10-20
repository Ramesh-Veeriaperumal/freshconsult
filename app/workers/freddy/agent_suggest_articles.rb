module Freddy
  class AgentSuggestArticles < BaseWorker
    include Redis::IntegrationsRedis
    sidekiq_options queue: :bot_email_reply, retry: 0, failures: :exhausted
    SERVICE = 'freshdesk'.freeze
    FREDDY_BOT = 'Freddy::Bot'.freeze
    FRANK_BOT = 'Bot'.freeze

    def perform(args)
      args = args.deep_symbolize_keys
      @ticket = account.tickets.where(id: args[:ticket_id]).first
      return unless ticket_eligible_to_suggestion?

      ml_response = fetch_ml_response
      Rails.logger.debug ml_response.inspect.to_s
      if ml_response['data'].empty?
        Rails.logger.info "No solution articles from ML for ticket #{@ticket.id}"
        return
      end
      solution_ids = ml_response['data'].collect { |response| response['id'] }
      @meta_articles = account.solution_article_meta.where('`solution_article_meta`.`id` IN (?)', solution_ids).preload(:primary_article).order("field(`solution_article_meta`.`id`, #{solution_ids.join ','})")
      if @meta_articles.any?
        if ml_response['cortex_id'].present?
          bot_id = ml_response['cortex_id']
          bot_type = FREDDY_BOT
        else
          bot_id = @ticket.portal.bot.id
          bot_type = FRANK_BOT
        end
        create_bot_response(bot_id, bot_type)
        send_email_notification if source_email?
      else
        Rails.logger.info "No articles found for solution ids from ML for the ticket #{@ticket.id}"
      end
    rescue Exception => e
      Rails.logger.error "Error sending Freddy email response::Exception:: #{e.message} for Account #{account.id}"
      NewRelic::Agent.notice_error(e, description: "Error sending Freddy email response::Exception:: #{e.message} for Account #{account.id}")
    end

    private

      def ticket_eligible_to_suggestion?
        (@ticket.portal.freddy_bot.present? || @ticket.portal.bot.present?) &&
          (ticket_source(Helpdesk::Source::EMAIL) || ticket_source(Helpdesk::Source::PORTAL))
      end

      def ticket_source(source)
        @ticket.source == source
      end

      def source_email?
        ticket_source(Helpdesk::Source::EMAIL) && (account.bot_email_channel_enabled? || account.email_articles_suggest_enabled?)
      end

      def fetch_ml_response
        response = RestClient::Request.execute(
          method: :post,
          url: FreddySkillsConfig[:agent_articles_suggest][:url],
          payload: ml_request_body,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => "Bearer #{jwt_token}"
          }
        )
        JSON.parse(response)['result']
      end

      def ml_request_body
        @query_id = UUIDTools::UUID.timestamp_create.hexdigest.to_s
        {
          size: 3,
          account_id: account.id.to_s,
          portal_id: @ticket.portal.id.to_s,
          ticket_id: @ticket.id.to_s,
          product_name: 'Freshdesk',
          feature_name: 'emailbot',
          channel: 'FAQSSUGGEST',
          subject: @ticket.subject,
          query: @ticket.ticket_body.description,
          query_html: @ticket.ticket_body.description_html,
          query_id: @query_id,
          locale: @ticket.portal.language
        }.to_json
      end

      def jwt_token
        JWT.encode payload, FreddySkillsConfig[:agent_articles_suggest][:secret], 'HS256', { 'alg': 'HS256', 'typ': 'JWT' }
      end

      def payload
        {}.tap do |claims|
          claims[:aud] = account.id.to_s
          claims[:exp] = Time.now.to_i + 10.minutes
          claims[:iat] = Time.now.to_i
          claims[:iss] = SERVICE
        end
      end

      def create_bot_response(bot_id, bot_type)
        suggested_hash = {}
        @meta_articles.each do |meta_article|
          suggested_hash[meta_article.id] = { title: meta_article.title, opened: false, folder_title: meta_article.solution_folder_meta.name }
        end
        account.bot_responses.create(ticket_id: @ticket.id, bot_id: bot_id, bot_type: bot_type, query_id: @query_id, suggested_articles: suggested_hash)
      end

      def send_email_notification
        Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::BOT_RESPONSE_TEMPLATE, @ticket, nil, freddy_suggestions: freddy_suggestions)
        # skipping send to cc here.Email Notification only for the requester.
      end

      def freddy_suggestions
        string = ''
        @meta_articles = @meta_articles.visible_to_all
        @meta_articles.each do |article|
          article_url = Rails.application.routes.url_helpers.support_solutions_article_url(article, host: article.account.host)
          article_full_url = article_url + '?query_id=' + @ticket.bot_response.query_id
          desc = article.article_body.desc_un_html.truncate(220)
          string << "<div><img src='#{BOT_CONFIG[:email_bot_article_cdn_url]}/images/bot_solution_article.png'
            height='13px' width='13px' style='vertical-align:middle; margin-bottom:2px'><a href='#{article_full_url}' style='text-decoration:none;
            color:#448EE1; font-weight:500; padding-left:4px;'> #{article.title}</a><div style='padding-left:20px; width:450px;
            text-align:justify; padding-bottom:20px;'>#{desc}<a href='#{article_full_url}' style='text-decoration:none; color:#448EE1;'> Read more </a></div></div>"
        end
        string
      end

      def account
        ::Account.current
      end
  end
end

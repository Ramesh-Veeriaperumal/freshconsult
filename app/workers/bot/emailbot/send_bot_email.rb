module Bot::Emailbot
  class SendBotEmail < BaseWorker
    sidekiq_options queue: :bot_email_reply, retry: 0, backtrace: true, failures: :exhausted

    def perform(args)
      args = args.deep_symbolize_keys
      @ticket = account.tickets.where(id: args[:ticket_id]).first 
      ml_response = fetch_ml_response
      if ml_response['data'].empty?
        Rails.logger.info "No solution articles from ML for ticket #{@ticket.id}" 
        return
      end
      solution_ids = ml_response['data'].collect { |response| response['id'] }
      @meta_articles = account.solution_article_meta.where('id IN (?)', solution_ids).preload(:primary_article)
      if @meta_articles.any?
        create_bot_response
        send_email_notification
      else
        Rails.logger.info "No articles found for solution ids from ML for the ticket #{@ticket.id}"
      end
    rescue Exception => e
      Rails.logger.error "Error sending Freddy email response::Exception:: #{e.message} for Account #{account.id}"
      NewRelic::Agent.notice_error(e, description: "Error sending Freddy email response::Exception:: #{e.message} for Account #{account.id}" )
    end

    private

      def fetch_ml_response
        response = RestClient::Request.execute(
          method: :post,
          url: "#{BOT_CONFIG[:email_bot_domain]}#{BOT_CONFIG[:email_bot_path]}",
          payload: ml_request_body,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => BOT_CONFIG[:ml_authorization_key]
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
          product_name: 'Freshdesk',
          feature_name: 'emailbot',
          subject: @ticket.subject,
          query: @ticket.ticket_body.description,
          query_html: @ticket.ticket_body.description_html,
          query_id: @query_id
        }.to_json
      end

      def create_bot_response
        suggested_hash = {}
        @meta_articles.each do |meta_article|
          suggested_hash[meta_article.id] = { title: meta_article.title, opened: false }
        end
        account.bot_responses.create(ticket_id: @ticket.id, bot_id: @ticket.portal.bot.id, query_id: @query_id, suggested_articles: suggested_hash)
      end

      def send_email_notification
        Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::BOT_RESPONSE_TEMPLATE, @ticket, nil, { freddy_suggestions: freddy_suggestions })
        #skipping send to cc here.Email Notification only for the requester.
      end

      def freddy_suggestions
        string = "<div>"
        @meta_articles.each do |article|
          article_url = Rails.application.routes.url_helpers.support_solutions_article_url(article, host: article.account.host)
          article_full_url = article_url + '?query_id=' + @ticket.bot_response.query_id
          desc = article.article_body.desc_un_html.truncate(220)
          string << "<div> <img src='#{BOT_CONFIG[:email_bot_article_cdn_url]}/images/bot_solution_article.png'
            height='13px' width='13px' style='vertical-align:middle; margin-bottom:2px'><a href='#{article_full_url}' style='text-decoration:none;
            color:#448EE1; font-weight:500; padding-left:4px;'> #{article.title}</a><div style='padding-left:20px; width:450px;
            text-align:justify;'>#{desc}<a href='#{article_full_url}' style='text-decoration:none; color:#448EE1;'> Read more </a><br><br></div></div>"
        end
        string += "</div>"
      end

      def account
        ::Account.current
      end
  end
end

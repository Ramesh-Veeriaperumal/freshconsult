class Tickets::BotResponseController < ApiApplicationController
  include TicketConcern
  include HelperConcern

  decorate_views

  def update
    @item.save ? render(action: :show) : render_custom_errors
  end

  private
    def scoper
      current_account.tickets
    end

    def before_load_object
      @ticket = scoper.find_by_display_id(params[:id])
      @ticket.present? ? verify_ticket_permission(api_current_user, @ticket) : log_and_render_404
    end

    def load_object
      @item = @ticket.bot_response
      head 204 unless @item
    end

    def validate_params
      validate_body_params(@item)
    end

    def constants_class
      'BotResponseConstants'.freeze
    end

    def sanitize_params
      articles = cname_params[:articles]
      articles.each do |article|
        article = article.symbolize_keys
        @item.assign_agent_feedback(article[:id], article[:agent_feedback])
      end
    end
end
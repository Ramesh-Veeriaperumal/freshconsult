module Channel
  module Bot
    class TicketsController < Channel::TicketsController

      skip_before_filter :check_privilege
      before_filter :check_bot_feature
      before_filter :validate_bot
      before_filter :set_bot_portal_as_current
      before_filter :set_bot_source
      after_filter :create_bot_ticket, only: :create

      BOT_TICKETS_CONSTANTS_CLASS = 'ApiBotTicketConstants'.freeze
      BOT_TICKETS_VALIDATION_CLASS = 'Bot::TicketValidation'.constantize

      private

        def constants_class
          BOT_TICKETS_CONSTANTS_CLASS
        end

        def validation_class
          BOT_TICKETS_VALIDATION_CLASS
        end

        def sanitize_params
          super
          @bot_external_id = params[cname].delete(:bot_external_id)
          @query_id = params[cname].delete(:query_id)
          @conversation_id = params[cname].delete(:conversation_id)
        end

        def check_bot_feature
          render_request_error(:require_feature, 403, feature: 'Support Bot') unless Account.current.support_bot_enabled?
        end

        def validate_bot
          @bot = current_account.bots.where(external_id: @bot_external_id).first
          render_request_error(:invalid_bot, 400, id: @bot_external_id) unless @bot
        end

        def set_bot_source
          @item.source = Helpdesk::Source::BOT
        end

        def create_bot_ticket
          bot_ticket = @ticket.build_bot_ticket(bot_id: @bot.id, query_id: @query_id, conversation_id: @conversation_id)
          bot_ticket.save
        end

        def set_bot_portal_as_current
          @current_portal = @bot.portal.make_current
        end
    end
  end
end

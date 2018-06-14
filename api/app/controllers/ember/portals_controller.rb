module Ember
  class PortalsController < ApiApplicationController
    include HelperConcern

    decorate_views

    around_filter :run_on_slave, only: [:bot_prerequisites]

    def index
      super
      response.api_meta = { count: @items.size }
    end

    def show
      return unless validate_query_params
    end

    def bot_prerequisites
      return unless validate_query_params
      return unless validate_delegator(@item, {})
      @pre_requisites = {
        tickets_count: tickets_count,
        articles_count: articles_count
      }
    end

    private

      def scoper
        current_account.portals
      end

      def constants_class
        'PortalConstants'.freeze
      end

      def load_objects
        @items = current_account.portals.all
      end

      def tickets_count
        current_account.count_es_enabled? ? ::Search::Filters::Docs.new([], []).count(Helpdesk::Ticket) : current_account.tickets.count
      end

      def articles_count
        Language.for_current_account.make_current
        count = @item.bot_article_meta.count(:id)
        Language.reset_current
        count
      end
  end
end

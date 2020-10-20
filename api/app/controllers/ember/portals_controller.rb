module Ember
  class PortalsController < ApiApplicationController
    include HelperConcern

    decorate_views

    around_filter :run_on_slave, only: [:index, :bot_prerequisites]

    def index
      super
      response.api_meta = { count: @items.size }
    end

    def show
      return unless validate_query_params
    end

    def update
      if current_account.subscription.sprout_plan?
          render_request_error :access_denied, 403 
          return false
      else
        assign_protected
        if params[cname].key?(:helpdesk_logo)
          params[cname]['helpdesk_logo'].present? ? update_logo : remove_logo
        end
      end

      @item.save ? render(:show) : render_errors(@item.errors)
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
        @items = current_account.portals.preload(:fav_icon, :product, :helpdesk_logo)
      end

      def preload_options
        [:helpdesk_logo]
      end

      def update_logo
        logo_data = { id: params[cname]['helpdesk_logo']['id'] }
        portal_delegator = PortalDelegator.new(@item, logo_data)
        if !portal_delegator.valid?
          render_custom_errors(portal_delegator, true)
        else
          portal_logo = portal_delegator.draft_logo
          @attachment = portal_logo if portal_logo
          build_helpdesk_logo
        end
      end

      def validate_params
        params[cname].permit(*PortalConstants::UPDATE_FIELDS)
        portal = PortalValidation.new(params[cname], @item, string_request_params?)
        render_custom_errors(agent, true) unless portal.valid?
      end

      def remove_logo
        @item.helpdesk_logo.destroy if @item.helpdesk_logo.present?
      end

      def assign_protected
        (@item[:preferences]).deep_merge!(params[cname][:preferences] || {})
      end

      def build_helpdesk_logo
        @attachment.description = 'mint_logo'
        @attachment.save!
        @item.helpdesk_logo = @attachment
      end

      def load_object
        @item = scoper.preload(preload_options).find_by_id(params[:id])
        log_and_render_404 unless @item
      end

      def tickets_count
        ::Search::Filters::Docs.new([], []).count(Helpdesk::Ticket)
      end

      def articles_count
        Language.for_current_account.make_current
        count = @item.bot_article_meta.count(:id)
        Language.reset_current
        count
      end
  end
end

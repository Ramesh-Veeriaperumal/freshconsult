module Ember
  class TicketTemplatesController < ApiApplicationController
    include TicketTemplateConstants
    include HelperConcern
    include Helpdesk::AccessibleElements
    include ParentChildHelper

    before_filter :ticket_template_permission?, only: [:show]

    def show
      @result = TicketTemplateDecorator.new(@item, {})
      handle_type_params
      @result = if current_account.parent_child_tickets_enabled? && params[:only_parent]
                  @result.to_hash_and_child_templates
                else
                  @result.to_full_hash
                end
    end

    def index
      @items = []
      if params[:filter] == "accessible"
        handle_type_params
        size = Helpdesk::TicketTemplate::TOTAL_SHARED_TEMPLATES
        @items = fetch_templates(["`ticket_templates`.id NOT IN (?) and
        `ticket_templates`.association_type IN (?)", '', set_assn_types], set_assn_types, nil, size, '')
      end
    end

    protected

      def requires_feature(feature)
        return if Account.current.tkt_templates_enabled?
        render_request_error(:require_feature, 403, feature: feature.to_s.titleize)
      end

    private

      def validate_filter_params
        validate_query_params
      end

      def feature_name
        FeatureConstants::TICKET_TEMPLATES
      end

      def constants_class
        :TicketTemplateConstants.to_s.freeze
      end

      def scoper
        current_account.prime_templates
      end

      def ticket_template_permission?
        render_request_error(:access_denied, 403) unless @item.visible_to_me?
      end

      def handle_type_params
        params[params[:type]] = true if params[:type].present?
      end
  end
end

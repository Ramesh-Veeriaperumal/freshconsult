module Ember
  module Tickets
    class AssociatesController < ApiApplicationController
      include TicketConcern
      include HelperConcern

      before_filter :ticket_permission?
      before_filter :link_tickets_enabled?, only: [:link]
      before_filter :feature_enabled?, only: [:prime_association]

      TICKET_ASSOCIATE_CONSTANTS_CLASS = :TicketAssociateConstants.to_s.freeze

      def link
        return unless validate_body_params(@item)
        return unless validate_delegator(@item)
        set_associations
        if @item.save
          head 204
        else
          render_errors(@item.errors)
        end
      end

      def prime_association
        return unless validate_delegator(@item)
        @prime_association = @item.related_ticket? ? @item.associated_prime_ticket('related') : @item.associated_prime_ticket('child')
      end

      private

        def scoper
          current_account.tickets
        end

        def load_object
          @item = scoper.find_by_display_id(params[:id])
          log_and_render_404 unless @item
        end

        def constants_class
          TICKET_ASSOCIATE_CONSTANTS_CLASS
        end

        def set_associations
          @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
          @item.tracker_ticket_id = params[:tracker_id]
        end

        def link_tickets_enabled?
          render_request_error(:require_feature, 403, feature: 'Link Tickets') unless Account.current.link_tkts_enabled?
        end

        def parent_child_tickets_enabled?
          render_request_error(:require_feature, 403, feature: 'Parent Child Tickets') unless Account.current.parent_child_tkts_enabled?
        end

        def feature_enabled?
          link_tickets_enabled? if @item.related_ticket?
          parent_child_tickets_enabled? if @item.child_ticket?
        end
    end
  end
end

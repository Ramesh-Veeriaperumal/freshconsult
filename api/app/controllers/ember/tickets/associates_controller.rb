module Ember
  module Tickets
    class AssociatesController < ApiApplicationController
      include TicketConcern
      include HelperConcern

      before_filter :ticket_permission?
      before_filter :load_object
      before_filter :link_tickets_enabled?, only: [:link, :unlink]
      before_filter :feature_enabled?, only: [:prime_association, :associated_tickets]

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

      def associated_tickets
        return log_and_render_404 unless @item.tracker_ticket? || @item.assoc_parent_ticket?
        load_associations
      end

      def unlink
        return unless validate_body_params(@item) && validate_delegator(@item)
        if @item.remove_associations!
          head 204
        else
          render_errors(@item.errors)
        end
      end

      def prime_association
        return log_and_render_404 unless @item.related_ticket? || @item.child_ticket?
        @prime_association = @item.related_ticket? ? @item.associated_prime_ticket('related') : @item.associated_prime_ticket('child')
        @permission        = current_user.has_ticket_permission?(@prime_association)
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
          @item.association_type  = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
          @item.tracker_ticket_id = params[:tracker_id]
        end

        def load_associations
          preload_models      = [:requester, :responder, :ticket_states, :ticket_status]
          conditions          = { display_id: @item.associates }
          per_page            = @item.assoc_parent_ticket? ? 10 : 30
          paginate_options    = { page: params[:page], per_page: per_page }
          @associated_tickets = current_account.tickets.preload(preload_models).where(conditions).paginate(paginate_options)
          @permissibles       = @associated_tickets.permissible(current_user)
        end

        def link_tickets_enabled?
          render_request_error(:require_feature, 403, feature: 'Link Tickets') unless Account.current.link_tkts_enabled?
        end

        def parent_child_tickets_enabled?
          render_request_error(:require_feature, 403, feature: 'Parent Child Tickets') unless Account.current.parent_child_tkts_enabled?
        end

        def feature_enabled?
          link_tickets_enabled? if @item.tracker_ticket? || @item.related_ticket?
          parent_child_tickets_enabled? if @item.assoc_parent_ticket? || @item.child_ticket?
        end
    end
  end
end

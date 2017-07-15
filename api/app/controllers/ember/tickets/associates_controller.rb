module Ember
  module Tickets
    class AssociatesController < ApiApplicationController
      include TicketConcern
      include HelperConcern
      include AssociateTicketsHelper

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

      def prime_association
        return log_and_render_404 unless @item.related_ticket? || @item.child_ticket?
        @prime_association = @item.related_ticket? ? @item.associated_prime_ticket('related') : @item.associated_prime_ticket('child')
        @last_broadcast_message = @item.last_broadcast_message
        @permission = current_user.has_ticket_permission?(@prime_association)
        @item = TicketDecorator.new(@prime_association, permission: @permission,
                                                        last_broadcast_message: @last_broadcast_message)
      end

      def unlink
        return unless validate_body_params(@item) && validate_delegator(@item)
        if @item.remove_associations!
          head 204
        else
          render_errors(@item.errors)
        end
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
    end
  end
end

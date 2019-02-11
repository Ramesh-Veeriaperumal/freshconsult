module Ember
  module Tickets
    class AssociatesController < ApiApplicationController
      include TicketConcern
      include HelperConcern
      include AssociateTicketsHelper

      before_filter :ticket_permission?
      before_filter :load_object
      before_filter :validate_filter_params, only: [:associated_tickets, :associated_tickets_count]
      before_filter :feature_enabled?, only: [:prime_association, :associated_tickets, :associated_tickets_count]

      TICKET_ASSOCIATE_CONSTANTS_CLASS = :TicketAssociateConstants.to_s.freeze

      def associated_tickets
        return log_and_render_404 unless @item.tracker_ticket? || @item.assoc_parent_ticket?
        load_associations(params['type'])
      end

      def prime_association
        return log_and_render_404 unless @item.related_ticket? || @item.child_ticket?
        @prime_association = @item.related_ticket? ? @item.associated_prime_ticket('related') : @item.associated_prime_ticket('child')
        @last_broadcast_message = @item.last_broadcast_message
        @permission = current_user.has_ticket_permission?(@prime_association)
        @item = TicketDecorator.new(@prime_association, permission: @permission,
                                                        last_broadcast_message: @last_broadcast_message)
      end

      def associated_tickets_count
        return log_and_render_404 unless @item.assoc_parent_ticket? || @item.tracker_ticket?
        return head 400 if @item.tracker_ticket? && params['type'] # Don't support tracker filter with type as the count may be huge.

        load_associates_count(params['type'])
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

        def load_associations type=nil
          preload_models      = [:requester, :responder, :ticket_states, :ticket_status]
          conditions          = type.present? ? { display_id: @item.associates, ticket_type: type } : { display_id: @item.associates }
          per_page            = @item.assoc_parent_ticket? ? 10 : 30
          paginate_options    = { page: params[:page], per_page: per_page }
          @associated_tickets = current_account.tickets.preload(preload_models).where(conditions).paginate(paginate_options)
          @permissibles       = @associated_tickets.permissible(current_user)
        end

        def load_associates_count type=nil
          associates = @item.associates
          count = type.present? ? current_account.tickets.where({ticket_type: type, display_id: associates}).size : associates.size
          @associated_tickets_by_count = { count: count }
        end

        def validate_filter_params
          params.delete("associate") if Rails.env.test?
          params.permit(*ApiTicketConstants::ASSOCIATED_TICKETS_FILTER, *ApiConstants::DEFAULT_INDEX_FIELDS)
          @ticket_filter = TicketFilterValidation.new(params, nil, string_request_params?)
          render_errors(@ticket_filter.errors, @ticket_filter.error_options) unless @ticket_filter.valid?
        end

    end
  end
end

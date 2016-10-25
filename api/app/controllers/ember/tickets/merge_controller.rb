module Ember
  module Tickets
    class MergeController < ApiApplicationController
      include TicketConcern

      before_filter :validate_merge_params, :load_target_ticket, :ticket_permission?, :load_source_tickets, :validate_source_tickets, only: [:merge]

      def merge
        merge_ticket = TicketMerge.new(@item, @source_tickets, params[cname])
        if merge_ticket.perform
          head 204
        else
          render_errors(merge: :"Unable to to complete the merge.")
        end
      end

      private

        def scoper
          current_account.tickets
        end

        def load_target_ticket
          @item = scoper.find_by_display_id(params[cname][:primary_id])
          log_and_render_404 unless @item
        end

        def validate_merge_params
          merge_ticket_validation = TicketValidation.new(merge_params, nil)
          render_errors(merge_ticket_validation.errors, merge_ticket_validation.error_options) unless merge_ticket_validation.valid?(:merge)
        end

        def merge_params
          (params[cname].present? && params.require(cname).permit(*ApiTicketConstants::MERGE_PARAMS)) || {}
        end

        def load_source_tickets
          @source_tickets = scoper.where(display_id: params[cname][:ticket_ids])
        end

        def validate_source_tickets
          merge_validation = TicketMergeDelegator.new(@item, params[cname].merge(source_tickets: @source_tickets))
          render_errors(merge_validation.errors, merge_validation.error_options) unless merge_validation.valid?
        end

        wrap_parameters(*ApiTicketConstants::MERGE_WRAP_PARAMS)
    end
  end
end

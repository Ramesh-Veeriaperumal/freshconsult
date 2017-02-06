module Ember
  class CannedResponsesController < ApiApplicationController
    include HelperConcern
    include TicketConcern
    decorate_views

    before_filter :canned_response_permission?, :load_ticket, :ticket_permission?, only: [:show]
    before_filter :filter_ids, only: :index

    MAX_IDS_COUNT = 10

    private

      def validate_filter_params
        params.permit(*ApiConstants::DEFAULT_INDEX_FIELDS, :ids)
      end

      def validate_url_params
        @validation_klass = 'CannedResponseFilterValidation'
        validate_query_params
      end

      def sideload_options
        @validator.include_array
      end

      def decorator_options
        options = {}
        if show?
          options[:sideload_options] = (sideload_options || [])
          options[:ticket] = @ticket
        end
        super(options)
      end

      def constants_class
        :CannedResponseConstants.to_s.freeze
      end

      def load_objects
        @items = scoper.where(id: @ids)
        @items.select!(&:visible_to_me?)

        # Instead of using validation to give 4xx response for bad ids,
        # we are going to tolerate and send response for the good ones alone.
        # Because the primary use case for this is Recently used Canned Responses
        log_and_render_404 if @items.blank?
      end

      def filter_ids
        @ids = params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?).first(MAX_IDS_COUNT)
        log_and_render_404 if @ids.blank?
      end

      def scoper
        current_account.canned_responses.preload(helpdesk_accessible: [:group_accesses, :user_accesses])
      end

      def load_ticket
        if params[:ticket_id]
          @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
          log_and_render_404 unless @ticket.present?
        end
      end

      def canned_response_permission?
        render_request_error(:access_denied, 403) unless @item.visible_to_me?
      end
  end
end

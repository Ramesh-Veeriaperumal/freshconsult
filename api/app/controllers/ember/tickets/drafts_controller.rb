module Ember
  module Tickets
    class DraftsController < ApiApplicationController
      include TicketConcern
      include HelperConcern
      include ParserUtil

      def save_draft
        return unless validate_body_params
        sanitize_draft_params
        return unless validate_delegator(nil, from_email: params[cname][:from_email])
        @ticket.draft.build(params[cname])
        return head 204 if @ticket.draft.save
        head 424
      end

      def show_draft
        @item = @ticket.draft if @ticket.draft.exists?
      end

      def clear_draft
        @ticket.draft.clear
        head 204
      end

      def self.wrap_params
        DraftConstants::WRAP_PARAMS
      end

      private

        def load_parent_ticket # Needed here in controller to find the item by display_id
          @ticket = current_account.tickets.find_by_param(params[:id], current_account)
          log_and_render_404 unless @ticket
          @ticket
        end

        def check_privilege
          return false unless super # break if there is no enough privilege.

          # load ticket and return 404 if ticket doesn't exists in case of APIs which has ticket_id in url
          return false unless load_parent_ticket
          verify_ticket_permission(api_current_user, @ticket) if @ticket
        end

        def sanitize_draft_params
          sanitize_body_params
          params[cname][:body] = Helpdesk::HTMLSanitizer.clean(params[cname][:body])
          DraftConstants::EMAIL_FIELDS.each do |field|
            params[cname][field] = fetch_valid_emails((params[cname][field] || []).to_a)
          end
          params[cname][:from_email] = (params[cname][:from_email] || '').to_s
        end

        def constants_class
          :DraftConstants.to_s.freeze
        end

        wrap_parameters(*wrap_params)
    end
  end
end

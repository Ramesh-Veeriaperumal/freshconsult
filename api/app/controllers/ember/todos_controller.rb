module Ember
  class TodosController < ApiApplicationController
    include HelperConcern
    include TicketConcern
    decorate_views(decorate_object: [:toggle])
    SINGULAR_RESPONSE_FOR = %w(create update toggle).freeze

    def index
      @items = params[:ticket_id] ? scoper.preload(:ticket) : paginate_items(scoper.preload(:ticket))
      response.api_meta = { count: scoper.count }
    end

    def create
      return unless validate_body_params
      @item.ticket_id = @ticket.id if @ticket
      @item.user_id = (@user || api_current_user).id # can be only api_current_user.id
      if @item.save
        render '/ember/todos/show'
      else
        render_custom_errors
      end
    end

    def update
      return unless validate_body_params
      if @item.update_attributes(params[cname])
        render '/ember/todos/show'
      else
        render_custom_errors
      end
    end

    def destroy
      if @item.destroy
        head 204
      else
        render_custom_errors
      end
    end

    def toggle
      return unless params
      @item.toggle(:deleted)
      if @item.save
        render '/ember/todos/show'
      else
        render_custom_errors
      end
    end

    private

      def validate_filter_params
        params.permit(*fields_to_validate)
        @filter = TodoValidation.new(params, nil, true)
        render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
      end

      def check_privilege
        return false unless super # break if there is no enough privilege.
        if (create? || update? || index?) && params[:ticket_id]
          @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
          unless @ticket.present?
            log_and_render_404
            return false
          end
          verify_ticket_permission(api_current_user, @ticket)
        end
      end

      def constants_class
        :TodoConstants.to_s.freeze
      end 

      def scoper
        return Helpdesk::Reminder unless index? # to handle validationerrors for update & create
        conditions = params[:ticket_id] ? { ticket_id: @ticket.id } : { user_id: (@user || api_current_user).id }
        Helpdesk::Reminder.where(conditions).order('id DESC')
      end
  end
end

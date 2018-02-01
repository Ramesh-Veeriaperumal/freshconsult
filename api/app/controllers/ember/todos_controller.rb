module Ember
  class TodosController < ApiApplicationController
    include HelperConcern
    include TicketConcern
    include TodoConstants
    decorate_views

    before_filter :verify_rememberable, only: [:create, :index]

    def index
      @items = paginate_items(fetch_reminders.
          with_resources(PRELOAD_RESOURCES_MAP[rememberable_type]))
      response.api_meta = { count: fetch_reminders.count(:id) }
    end

    def create
      @item.user_id = api_current_user.id
      @item.company_id = @rememberable.customer_id if rememberable_type == :contact
      if @item.save
        render '/ember/todos/show'
      else
        render_custom_errors
      end
    end

    def update
      sanitize_update_params
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

    private

      def decorator_options
        rememberable_type ? 
          super({ "#{rememberable_type}": rememberable }) : super
      end

      def verify_rememberable
        return head 404 if rememberable_type && rememberable.nil?
      end

      def validate_filter_params
        params.permit(*fields_to_validate)
        @filter = TodoValidation.new(params, nil, true)
        render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
      end

      def validate_params
        validate_body_params
      end

      def sanitize_update_params
        ParamsHelper.assign_and_clean_params(TODO_PARAMS_MAPPINGS, params[cname])
      end

      def after_load_object
        verify_user_permission(api_current_user, @item) if rememberable_type.nil?
      end

      def check_privilege
        return false unless super # break if there is no enough privilege.
        if rememberable_type == :ticket && rememberable
          return verify_ticket_permission(api_current_user, rememberable) 
        end
        true
      end

      def constants_class
        :TodoConstants.to_s.freeze
      end

      def fetch_reminders
        if rememberable
          @rememberable.send(REMINDERS[rememberable_type])
        else
          api_current_user.reminders
        end
      end

      def scoper
        return @rememberable.send(REMINDERS[rememberable_type]) if rememberable
        Helpdesk::Reminder
      end

      def rememberable
        return @rememberable if @rememberable
        if rememberable_type.present?
          if reminder.present?
            @rememberable = @reminder.send(rememberable_type)
          elsif FIND_REMEMBERABLE[rememberable_type]
            @rememberable = send(FIND_REMEMBERABLE[rememberable_type],
                                  params[:rememberable_id])
          end  
        end
      end

      def find_ticket(display_id)
        current_account.tickets.visible.find_by_display_id(display_id)
      end

      def find_user(id)
        current_account.all_users.find_by_id(id)
      end

      def find_company(id)
        current_account.companies.find_by_id(id)
      end

      def resource
        @resource ||= TYPE_TO_RESOURCE_MAP[rememberable_type]
      end

      def rememberable_type
        return @rememberable_type if @rememberable_type
        @rememberable_type = reminder ? reminder.rememberable_type : 
            params[:type].try(:to_sym)
      end

      def reminder
        return @reminder if @reminder
        if update? || destroy?
          @reminder = Helpdesk::Reminder.find_by_id(params[:id])
        end
      end
  end
end
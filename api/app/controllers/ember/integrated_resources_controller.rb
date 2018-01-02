module Ember
  class IntegratedResourcesController < ApiApplicationController
    include TicketConcern
    include HelperConcern

    decorate_views
    before_filter :validate_ticket_permission_for_create, only: [:create]
    before_filter :check_ticket_permission_for_destroy, only: [:destroy]

    def create
      return unless validate_body_params
      installed_application = current_account.installed_applications.find_by_id(params[:integrated_resource][:installed_application_id])
      if params[:integrated_resource][:local_integratable_type] == ::IntegratedResourceConstants::TICKET && 
        !google_calendar_app?(installed_application) # Temporary Hack for google calendar. Google calendar associates events with ticket's display ID and not the ID
        ticket_id = params[:integrated_resource][:local_integratable_id]
        ticket = fetch_ticket_using_display_id(ticket_id)
        params[:integrated_resource][:local_integratable_id] = ticket.id
      end
      application_id = params[:application_id].to_i
      params[:integrated_resource][:account] = Account.current
      params.delete(:application_id)
      params['application_id'] = application_id
      @item = Integrations::IntegratedResource.createResource(params)
      if @item.blank?
        return render_custom_errors
      else
        render '/ember/integrated_resources/show'
      end
    end

    def destroy
      resource = { integrated_resource: { id: @item.id, account: Account.current } }
      Integrations::IntegratedResource.deleteResource(resource)
      head 204
    end

    private

      def validate_params
        params[cname].permit(*fields_to_validate)
        resource = IntegratedResourceValidation.new(params[cname], nil, true)
        render_custom_errors(resource, true) unless resource.valid?
      end

      def load_objects
        if params[:local_integratable_type] == ::IntegratedResourceConstants::TICKET
          ticket = fetch_ticket_using_display_id(params[:local_integratable_id])
          if verify_ticket_state ticket
            installed_application = current_account.installed_applications.find_by_id(params[:installed_application_id])
            local_integratable_lookup_column = google_calendar_app?(installed_application) ? "display_id" : "id" # Temporary Hack for google calendar. Google calendar associates events with ticket's display ID and not the ID
            @items = Integrations::IntegratedResource.where(account_id: current_account.id, 
              installed_application_id: params[:installed_application_id], local_integratable_id: ticket.send(local_integratable_lookup_column))
          end
        else
          @items = Integrations::IntegratedResource.where(installed_application_id: params[:installed_application_id], local_integratable_id: params[:local_integratable_id])
        end
      end

      def google_calendar_app?(installed_application)
        return false unless installed_application
        installed_application.application.name == Integrations::Application::APP_NAMES[:google_calendar]
      end

      def validate_filter_params
        @constants_klass = 'IntegratedResourceConstants'
        @validation_klass = 'IntegratedResourceFilterValidation'
        validate_query_params
      end

      def scoper
        return Integrations::IntegratedResource unless index?
      end

      def constants_class
        :IntegratedResourceConstants.to_s.freeze
      end

      def fetch_ticket_using_display_id(display_id)
        current_account.tickets.find_by_display_id(display_id)
      end

      def check_ticket_permission_for_destroy
        log_and_render_404 unless @item.id
        integ_resource = Integrations::IntegratedResource.find_by_id(@item.id)
        log_and_render_404 unless integ_resource
        local_integratable_type = integ_resource.local_integratable_type
        if local_integratable_type == ::IntegratedResourceConstants::TICKET
          ticket = load_ticket_for_resource_destruction
          verify_ticket_state ticket
        end
      end

      def load_ticket_for_resource_destruction
        if google_calendar_app?(@item.installed_application)
          Account.current.tickets.find_by_display_id(@item.local_integratable_id)
        else
          Account.current.tickets.find_by_id(@item.local_integratable_id)
        end
      end

      def fetch_ticket_using_workable_id(local_integratable_id)
        time_sheet = Account.current.time_sheets.find_by_id(local_integratable_id)
        return nil unless time_sheet
        fetch_ticket_using_display_id(time_sheet.workable.display_id)
      end

      def verify_ticket_state(ticket)
        if ticket.nil?
          log_and_render_404
          return false
        end
        verify_ticket_state_and_permission(api_current_user, ticket)
      end

      def validate_ticket_permission_for_create
        ticket = nil
        if params[:integrated_resource][:local_integratable_type] == ::IntegratedResourceConstants::TICKET
          local_integratable_id = params[:integrated_resource][:local_integratable_id]
          ticket = fetch_ticket_using_display_id(local_integratable_id)
        elsif params[:integrated_resource][:local_integratable_type] == ::IntegratedResourceConstants::TIMESHEET
          ticket = fetch_ticket_using_workable_id(params[:integrated_resource][:local_integratable_id])
        end
        verify_ticket_state ticket
      end
  end
end

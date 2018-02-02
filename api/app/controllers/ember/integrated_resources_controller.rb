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
      if params[:integrated_resource][:local_integratable_type] == ::IntegratedResourceConstants::TICKET && !app_uses_display_id?(installed_application)
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
            @items = Integrations::IntegratedResource.where(account_id: current_account.id, 
              installed_application_id: params[:installed_application_id],
              local_integratable_id: ticket.send(local_integratable_lookup_column(installed_application)))
          end
        else
          @items = Integrations::IntegratedResource.where(installed_application_id: params[:installed_application_id], local_integratable_id: params[:local_integratable_id])
        end
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
          verify_ticket_state load_ticket_for_resource_destruction
        end
      end

      def app_uses_display_id?(installed_application)
        # Some apps associate the integrated resource with the display ID and not the real ID.
        return false unless installed_application
        IntegratedResourceConstants::INTEGRATIONS_USING_DISPLAY_ID.include?(installed_application.application.name)
      end

      def local_integratable_lookup_column(installed_application)
        (app_uses_display_id?(installed_application)) ? 'display_id' : 'id'
      end

      def load_ticket_for_resource_destruction
        Account.current.tickets.where(local_integratable_lookup_column(@item.installed_application).to_sym => @item.local_integratable_id).first
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
          ticket = fetch_ticket_using_display_id(params[:integrated_resource][:local_integratable_id])
        elsif params[:integrated_resource][:local_integratable_type] == ::IntegratedResourceConstants::TIMESHEET
          ticket = fetch_ticket_using_workable_id(params[:integrated_resource][:local_integratable_id])
        end
        verify_ticket_state ticket
      end
  end
end

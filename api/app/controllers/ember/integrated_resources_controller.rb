module Ember
  class IntegratedResourcesController < ApiApplicationController
    include TicketConcern
    include HelperConcern

    decorate_views
    before_filter :validate_ticket_permission, only: [:create,:destroy]
    
    def create
      return unless validate_body_params
      if params[:integrated_resource][:local_integratable_type] == IntegratedResourceConstants::TICKET
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
        if params[:local_integratable_type] == 'ticket'
          ticket = fetch_ticket_using_display_id(params[:local_integratable_id])
          @items = Integrations::IntegratedResource.where(installed_application_id: params[:installed_application_id], local_integratable_id: ticket.id)
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

      def validate_ticket_permission
        local_integratable_id = nil
        if params[:integrated_resource][:local_integratable_type] == IntegratedResourceConstants::TICKET
          local_integratable_id = params[:integrated_resource][:local_integratable_id]
        elsif  params[:integrated_resource][:local_integratable_type] == IntegratedResourceConstants::TIMESHEET
          time_sheet_id = params[:integrated_resource][:local_integratable_id]
          local_integratable_id = Account.current.time_sheets.find_by_id(time_sheet_id)
        else
          integ_resource = Integrations::IntegratedResource.find(@item.id)
          local_integratable_id = integ_resource.local_integratable_id
        end
        return log_and_render_404 unless local_integratable_id
        ticket = current_account.tickets.find_by_display_id(local_integratable_id)
        if ticket
          return verify_ticket_state_and_permission(api_current_user, ticket)
        else
          log_and_render_404
          false
        end
      end
  end
end

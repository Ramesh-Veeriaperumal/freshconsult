module Ember
class IntegratedResourcesController < ApiApplicationController
	include TicketConcern
	include HelperConcern

	decorate_views

  def create
    return unless validate_body_params
      params.with_indifferent_access
      if (params[:integrated_resource][:local_integratable_type] === "Helpdesk::Ticket")
        ticketId = params[:integrated_resource][:local_integratable_id]
        ticket = fetch_ticket_using_display_id(ticketId)
        if ticket.nil?
          render_custom_errors
        else
          params[:integrated_resource].delete(:local_integratable_id)
          params[:integrated_resource].merge!({:local_integratable_id => ticket.id})
        end
      end

      applicationId = params[:application_id].to_i
      params[:integrated_resource].merge!({:account => @current_account})
      params.delete(:application_id)
      params.merge!({"application_id" => applicationId})
      @item = Integrations::IntegratedResource.createResource(params)
      if @item.blank?
        render_custom_errors
      else
        render '/ember/integrated_resources/show'
      end      
  end

  def destroy
    resource = { :integrated_resource => { :id => @item.id, :account => @current_account}}
    Integrations::IntegratedResource.deleteResource(resource)
    head 204
  end


	private

	def load_objects()
    if params[:local_integratable_type] == 'ticket'
      ticket = fetch_ticket_using_display_id(params[:local_integratable_id])
  	   @items =  Integrations::IntegratedResource.where(:installed_application_id => params[:installed_application_id], :local_integratable_id => ticket.id)
    else
       @items =  Integrations::IntegratedResource.where(:installed_application_id => params[:installed_application_id], :local_integratable_id => params[:local_integratable_id])
    end
  end

  def validate_filter_params
    params.permit(*fields_to_validate)
    @filter = IntegratedResourceValidation.new(params, nil, true)
    render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
  end

  def scoper
    return Integrations::IntegratedResource unless index?
  end

  def constants_class
   :IntegratedResourceConstants.to_s.freeze
  end 

  def fetch_ticket_using_display_id (display_id)
    current_account.tickets.where(:display_id => display_id).first
  end

end
end

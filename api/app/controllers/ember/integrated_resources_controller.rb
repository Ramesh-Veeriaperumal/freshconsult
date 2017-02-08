module Ember
class IntegratedResourcesController < ApiApplicationController
	include TicketConcern
	include HelperConcern

	decorate_views

	private

	def scoper
		current_account.installed_applications.find(params[:installed_application_id])
	end

	def load_objects(items = scoper)
  	@items =  Integrations::IntegratedResource.where(:installed_application_id => params[:installed_application_id], :local_integratable_id => params[:local_integratable_id])
  end


  def validate_filter_params
    params.permit(*fields_to_validate)
    @filter = IntegratedResourceValidation.new(params, nil, true)
    render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
  end

  def constants_class
   :IntegratedResourceConstants.to_s.freeze
  end 

end
end



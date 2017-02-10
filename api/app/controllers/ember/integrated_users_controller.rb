module Ember 
	class IntegratedUsersController < ApiApplicationController
	decorate_views

	private

	def load_objects
		@items =  Integrations::UserCredential.where(:installed_application_id => params[:installed_application_id],:user_id =>params[:user_id])
	end

	def validate_filter_params
		params.permit(*IntegratedUserConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
    	@filter = IntegratedUserValidation.new(params, nil, true)
    	render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
  	end

	end
end
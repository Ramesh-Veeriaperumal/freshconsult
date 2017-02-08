module Ember
class InstalledApplicationsController < ApiApplicationController
	decorate_views

	private

	def scoper
		current_account.installed_applications.includes(:application)
	end

	def load_objects(items = scoper)
		@items = params[:name] ? scoper.where(*filter_conditions) : items
   	end

   	def filter_conditions
   		app_names = params[:name].split(',')
   		['applications.name in (?)', app_names]
    end

    def validate_filter_params
    	params.permit(*InstalledApplicationConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
    	@filter = InstalledApplicationValidation.new(params, nil, true)
    	render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
  	end

  	def constants_class
   		:InstalledApplicationConstants.to_s.freeze
  	end
end
end


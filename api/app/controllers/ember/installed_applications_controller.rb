module Ember
class InstalledApplicationsController < ApiApplicationController
	decorate_views

	private

	def scoper
		#current_account.installed_applications.preload(:application)
		current_account.installed_applications.includes(:application).all

	end

	def load_objects(items = scoper)
    	@items = items
   	end
end
end


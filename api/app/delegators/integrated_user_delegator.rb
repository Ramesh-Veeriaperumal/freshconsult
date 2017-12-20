class IntegratedUserDelegator < BaseDelegator
	attr_accessor :installed_application_id
	validate :integrated_user_presence

	def initialize(request_params)
		@installed_application_id = request_params[:installed_application_id]
	end

	def integrated_user_presence
		errors[:installed_application_id] << :"is invalid" if !Account.current.installed_applications.exists?(id: @installed_application_id)
	end
end
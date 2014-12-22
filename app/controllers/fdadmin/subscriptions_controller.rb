class Fdadmin::SubscriptionsController < Fdadmin::DevopsMainController

	include Fdadmin::SubscriptionControllerMethods


	def display_subscribers
		subscription_summary = {}
		subscription_summary[:subscriptions] = fetch_subscription_details(search(params[:search]))
		respond_to do |format|
			format.json do
				render :json => subscription_summary
			end
		end
	end

end

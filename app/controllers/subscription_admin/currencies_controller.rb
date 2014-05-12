class SubscriptionAdmin::CurrenciesController < ApplicationController
	include AdminControllerMethods

	def index
		Subscription::Currency.all.each do |currency|
			instance_variable_set "@#{currency.name}_revenue", fetch_revenue(currency)
			instance_variable_set "@#{currency.name}_revenue_in_usd", usd_equivalent(currency)
		end
	end

	def update
		Sharding.run_on_shard(:shard_1) do
			currency = Subscription::Currency.find_by_id(params[:id])
			currency.update_attributes(params[:currency])
		end
		redirect_to :action => :index		
	end

	private
		def fetch_revenue(currency)			
			cumilative_count { Subscription.fetch_monthly_revenue(currency) }
		end

		def usd_equivalent(currency)
			(fetch_revenue(currency) * currency.exchange_rate).to_f
		end

		def check_admin_user_privilege
      if !(current_user and current_user.has_role?(:currency))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
		end

end
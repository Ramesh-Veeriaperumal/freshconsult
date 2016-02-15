class Fdadmin::FreshfoneStats::UsageController < Fdadmin::DevopsMainController

	include Fdadmin::FreshfoneStatsMethods
 
	def global_conference_usage_csv
	  render :json => Freshfone::Account.global_conference_usage(params[:startDate], params[:endDate])
	end

	def global_conference_usage_csv_by_account
	  render :json =>  account.freshfone_account.global_conference_usage(params[:startDate], params[:endDate])
	end
	
end
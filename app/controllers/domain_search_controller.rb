class DomainSearchController < ApplicationController

  skip_filter filter_chain
  around_filter :select_shard

  def locate_domain
    agents = User.technicians.find_all_by_email(params[:user_email])
    unless agents.empty?
      urls = agents.collect{ |agent| agent.account.host }
      UserNotifier.deliver_helpdesk_url_reminder(params[:user_email], urls)
	  end

    render :json => { :available => agents.present? }, :callback => params[:callback]
  end

  def select_shard(&block)
  	Sharding.execute_on_all_shards do
  		yield
  	end
  end
  
end
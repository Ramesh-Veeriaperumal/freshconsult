class DomainSearchController < ApplicationController
  
  skip_filter filter_chain
  before_filter :unset_current_account

  def locate_domain
    Sharding.execute_on_all_shards do
      agents = User.technicians.find_all_by_email(params[:user_email])
      unless agents.empty?
        urls = agents.collect{ |agent| agent.account.host }
        UserNotifier.deliver_helpdesk_url_reminder(params[:user_email], urls)
      end
    end

    render :json => { :available => agents.present? }, :callback => params[:callback]
  end

end
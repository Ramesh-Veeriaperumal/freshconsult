class DomainSearchController < ApplicationController
  
  skip_filter filter_chain
  before_filter :unset_current_account

  def locate_domain
    agents = urls = []
    
    Sharding.execute_on_all_shards do
      agents = User.technicians.find_all_by_email(params[:user_email])
      agents.each do |agent|
        account = agent.account
        urls.push(account.host)
      end
    end
        
    UserNotifier.deliver_helpdesk_url_reminder(params[:user_email], urls) if agents.present?
    render :json => { :available => agents.present? }, :callback => params[:callback]
  end

end
class DomainSearchController < ApplicationController
  
  skip_filter filter_chain
  before_filter :unset_current_account, :ensure_email

  def locate_domain
    agents = urls = []
    
    Sharding.execute_on_all_shards do
      agents = User.technicians.find_all_by_email(params[:user_email])
      agents.each do |agent|
        account = agent.account
        urls.push(account.host)
      end
    end
        
    urls.uniq!
    UserNotifier.deliver_helpdesk_url_reminder(params[:user_email], urls) if urls.present?
    render :json => { :available => urls.present? }, :callback => params[:callback]
  end

  private
    def ensure_email
      if params[:user_email].blank?
        render :json => { :available => false }, :callback => params[:callback]
      end
    end

end
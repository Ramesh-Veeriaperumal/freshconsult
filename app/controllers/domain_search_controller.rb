class DomainSearchController < ActionController::Base
  
  # TODO-RAILS3 Need to cross check skiping whole filter chain, now this call is inheirted from 
  # ActionController::Base instead of ApplicationController
  #skip_filter filter_chain
  before_filter :ensure_email#, :unset_current_account
  protect_from_forgery

  def locate_domain

    # Get the list of associated accounts from dynamodb for a given email id
    associated_accounts = AdminEmail::AssociatedAccounts.find params[:user_email]

    # Get the host details for each accounts and store it for user notification.
    urls = associated_accounts.map(&:host)
        
    urls.uniq!
    UserNotifier.helpdesk_url_reminder(params[:user_email], urls) if urls.present?
    render :json => { :available => urls.present? }, :callback => params[:callback]
  end

  private
    def ensure_email
      if params[:user_email].blank?
        render :json => { :available => false }, :callback => params[:callback]
      end
    end

end
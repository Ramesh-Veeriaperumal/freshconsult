class SubscriptionAdmin::AccountsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  
  skip_before_filter :check_account_state
  
  def index
    @accounts = search(params[:search])
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def agents
    @accounts = Account.find(:all, :include => :all_agents).sort_by { |u| -u.all_agents.count }
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def helpdesk_urls
    @accounts = Account.all(:conditions => ["helpdesk_url is not null and helpdesk_url != ?",""])
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def tickets
    @accounts = Account.find(:all, :include => :tickets).sort_by { |u| -u.tickets.size }   
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def search(search)
    if search
      Account.find(:all, :conditions => ['full_domain LIKE ?', "%#{search}%"],:include => :subscription)
    elsif  !params[:start_date].blank? and !params[:end_date].blank?
      Account.find(:all,
                   :joins => "INNER JOIN subscriptions on accounts.id = subscriptions.account_id ",
                   :conditions => ['next_renewal_at between ? and ?', "#{params[:start_date]}","#{params[:end_date]}"]) 
    else
      Account.find(:all,:include => :subscription, :order => 'accounts.created_at desc')
    end
  end
  
end

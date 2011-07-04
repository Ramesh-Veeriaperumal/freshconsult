class SubscriptionAdmin::AccountsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  
  skip_before_filter :check_account_state
  
  def index
    @accounts = search(params[:search])
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30, :order => 'accounts.created_at desc')
  end
  
  def agents
    @accounts = Account.find(:all, :include => :users, :conditions => ['user_role != ?', User::USER_ROLES_KEYS_BY_TOKEN[:customer]]).sort_by { |u| -u.users.size }
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def helpdesk_urls
    @accounts = Account.all(:conditions => "helpdesk_url is not null and helpdesk_url != ”")
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def tickets
    @accounts = Account.find(:all, :include => :tickets, :conditions => ['user_role != ?', User::USER_ROLES_KEYS_BY_TOKEN[:customer]]).sort_by { |u| -u.tickets.size }   
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def search(search)
    if search
      Account.find(:all, :conditions => ['full_domain LIKE ?', "%#{search}%"],:include => :subscription)
    else
      Account.find(:all,:include => :subscription)
    end
  end
  
end

class SubscriptionAdmin::AccountsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  
  def index
    @accounts = search(params[:search])
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30, :order => 'accounts.created_at desc')
  end
  
  def agents
    @accounts = Account.all(:select => "#{Account.table_name}.*, COUNT(#{User.table_name}.id) number_of_agents",
         :joins => [:users,:subscription],
         :conditions => ['user_role != ? and state = ?', User::USER_ROLES_KEYS_BY_TOKEN[:customer],"trial"],
         :order => "number_of_agents")
     @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def helpdesk_urls
    @accounts = Account.all(:conditions => "helpdesk_url is not null")
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def tickets
    @accounts = Account.all(:select => "#{Account.table_name}.*, COUNT(#{Helpdesk::Ticket.table_name}.id) number_of_tickets",
         :joins => :tickets,
          :order => "number_of_tickets")
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

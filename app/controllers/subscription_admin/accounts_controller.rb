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
  
  def tickets
    @accounts = Account.find(:all, :include => :tickets).sort_by { |u| -u.tickets.size }   
    @accounts = @accounts.paginate( :page => params[:page], :per_page => 30)
  end
  
  def renewal_csv
    if !params[:from_date].blank? and !params[:to_date].blank?
      params[:start_date] = params[:from_date]
      params[:end_date] = params[:to_date]
      @accounts = search
      csv_string = CSVBridge.generate do |csv| 
      # header row 
      csv << ["name","full_domain","contact name","email","phone","Time Zone","created_at","next_renewal_at"] 
 
      # data rows 
      @accounts.each do |acc|
        sub = acc.subscription
        csv << [acc.name, acc.full_domain, acc.admin_first_name, acc.admin_email, acc.admin_phone, acc.time_zone,acc.created_at.strftime('%Y-%m-%d'),sub.next_renewal_at.strftime('%Y-%m-%d')] 
      end 
    end
    # send it to the browsah
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=trials.csv" 
    else
      flash[:notice] = "Please search and export to csv"
      redirect_to '/accounts'
    end
  end
  
  def search(search=nil)
    if search
      Account.find(:all, :conditions => ['full_domain LIKE ?', "%#{search}%"],:include => :subscription)
    elsif  !params[:start_date].blank? and !params[:end_date].blank?
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      Account.find(:all,
                   :joins => "INNER JOIN subscriptions on accounts.id = subscriptions.account_id ",
                   :conditions => ['next_renewal_at between ? and ? and state = ? ', "#{Time.parse(params[:start_date]).to_s(:db)}","#{Time.parse(params[:end_date]).to_s(:db)}","trial"]) 
   else
      Account.find(:all,:include => :subscription, :order => 'accounts.created_at desc')
    end
  end
  
end

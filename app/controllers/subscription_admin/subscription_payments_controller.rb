class SubscriptionAdmin::SubscriptionPaymentsController < ApplicationController
  skip_before_filter :check_account_state
  include ModelControllerMethods
  include AdminControllerMethods
  before_filter :set_selected_tab  
  
  def index
    @total_revenue = SubscriptionPayment.calculate(:sum, :amount)
    @payments = search
    @payments = @payments.paginate( :page => params[:page], :per_page => 30)
    
  end
  
  protected
  
  def search
    if !params[:start_date].blank? and !params[:end_date].blank?
      @revenue = SubscriptionPayment.calculate(:sum, :amount, :conditions => ['created_at between ? and  ?', "#{params[:start_date]}","#{params[:end_date]}"] )
      SubscriptionPayment.find(:all, :conditions => ['created_at between ? and  ?', "#{params[:start_date]}","#{params[:end_date]}"])
    else
      @revenue = SubscriptionPayment.calculate(:sum, :amount, :conditions => { :created_at => (Time.now.beginning_of_month .. Time.now.end_of_month) })
      SubscriptionPayment.find(:all, :order => 'created_at desc')
    end
  end
  
  def set_selected_tab
     @selected_tab = :payments
  end
  
end
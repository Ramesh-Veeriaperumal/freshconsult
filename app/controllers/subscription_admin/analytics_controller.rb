class SubscriptionAdmin::AnalyticsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods

   before_filter :set_selected_tab

   
  def index
   @inactive_accounts = {}
   accounts = Helpdesk::Note.maximum(:created_at,
  			:joins => "INNER join subscriptions on helpdesk_notes.account_id = subscriptions.account_id",
  			:conditions => "subscriptions.state = 'active' and helpdesk_notes.incoming = 0 ",
  			:group => "helpdesk_notes.account_id",
  			:having => "max(helpdesk_notes.created_at) < '#{parse_date}'"
  			)
   accounts.each { |account_id,date|  @inactive_accounts.store(Account.find(account_id),date.strftime("%d %b, %Y"))}
		   
  end

  protected

  def parse_date
    params[:start_date].nil? ? (Time.zone.now.ago 1.week).beginning_of_day.to_s(:db) : 
        Time.zone.parse(params[:start_date]).beginning_of_day.to_s(:db) 
  end

  def set_selected_tab
     @selected_tab = :analytics
  end
  
end
class Freshfone::Payment < ActiveRecord::Base
	set_table_name :freshfone_payments

	belongs_to_account
	attr_protected :account_id

  after_commit_on_create :set_usage_trigger

  def self.last_month_purchased_credits
    sum(:purchased_credit, :conditions => { 
      :created_at => (1.month.ago.beginning_of_month..1.month.ago.end_of_month.end_of_day) }).to_f
  end

  private
    def set_usage_trigger
      return if account.freshfone_credit.zero_balance?

      trigger_options = { :trigger_type => :credit_overdraft,
                          :account_id => account.id,
                          :purchased_credit => purchased_credit,
                          :usage_category => "totalprice" }
      Resque.enqueue(Freshfone::Jobs::UsageTrigger, trigger_options)
    end
    
end
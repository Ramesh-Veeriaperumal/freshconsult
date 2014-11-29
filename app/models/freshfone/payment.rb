class Freshfone::Payment < ActiveRecord::Base
	set_table_name :freshfone_payments

	belongs_to_account
	attr_protected :account_id

  after_commit_on_create :set_usage_trigger

  private
    def set_usage_trigger
      return if account.freshfone_credit.zero_balance? || !status

      trigger_options = { :trigger_type => :credit_overdraft,
                          :account_id => account.id,
                          :purchased_credit => purchased_credit,
                          :usage_category => "totalprice" }
      Resque.enqueue(Freshfone::Jobs::UsageTrigger, trigger_options)
    end
    
end
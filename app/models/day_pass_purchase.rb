class DayPassPurchase < ActiveRecord::Base
  STATUS = { :success => 1, :failure => 2 } #Original plan was to introduce a few more descriptive states...
  STATUS_BY_VALUE = STATUS.invert
  
  PAID_WITH = { :credit_card => 1, :referral => 2 }
  PAID_WITH_BY_TYPE = PAID_WITH.invert
  
  belongs_to :account
  belongs_to :payment, :polymorphic => true
  
  def success?
    status == STATUS[:success]
  end
  
  def paid_width_type
    PAID_WITH_BY_TYPE[paid_with]
  end
end

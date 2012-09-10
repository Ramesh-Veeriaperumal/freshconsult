class AchievedQuest < ActiveRecord::Base

  belongs_to_account
  
  belongs_to :user
  belongs_to :quest

  attr_protected :account_id

end

class AchievedQuest < ActiveRecord::Base

  self.primary_key = :id
  belongs_to_account
  
  belongs_to :user
  belongs_to :quest

  attr_protected :account_id
end

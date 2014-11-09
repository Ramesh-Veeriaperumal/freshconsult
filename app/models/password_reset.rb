class PasswordReset < ActiveRecord::Base
  self.primary_key = :id
  include TokenGenerator
  
  belongs_to :user
  
  after_create :send_email
  
  protected
  
    def send_email
      SubscriptionNotifier.password_reset(self)
    end
end

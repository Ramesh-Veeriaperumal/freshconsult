# encoding: utf-8
class UserEmail < ActiveRecord::Base

  # include Users::Activator
  # include ActionController::UrlWriter

  EMAIL_REGEX = /(\A[-A-Z0-9.'’_%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,4}|museum|travel)\z)/i

  belongs_to :user
  belongs_to_account
  validates_presence_of :email
  validates_format_of :email, :with => EMAIL_REGEX
  validates_uniqueness_of :email, :scope => [:account_id]
  before_create :set_token
  #before_update :drop_authorization, :if => :check_email_changed?
  #before_destroy :drop_authorization

  # def self.find_email_using_perishable_token(token, age)
  #   return if token.blank?
    
  #   age = age.to_i
  #   conditions_sql = "perishable_token = ?"
  #   conditions_subs = [token]
  #   if age > 0
  #     conditions_sql += " and updated_at > ?"
  #     conditions_subs << age.seconds.ago
  #   end
  #   find(:first, :conditions => [conditions_sql, *conditions_subs])
  # end

  # def check_email_changed?
  #   (self.email_changed?)
  # end

  # def mark_as_verified
  #   self.update_attribute(:verified, true) if !self.verified?
  # end

  #  def self.user_for_email(email, scoper=nil)
  #    user_email = (scoper || UserEmail).find_by_email(email)
  #    user_email ? user_email.user : nil
  #  end

  # def self.user_for_email(email)
  #   user_email = find_by_email(email)
  #   user_email ? user_email.user : nil
  # end

  # protected

  #   def drop_authorization
  #     self.user.authorizations.each do |auth|
  #       auth.destroy
  #     end 
  #   end

  private

    def set_token(portal=nil)
      self.perishable_token = user.perishable_token
      #self.perishable_token = Authlogic::Random.friendly_token
      # if !primary_role? and self.user.active?
      #     deliver_contact_activation_email if (!email.blank?)
      # end
    end
end

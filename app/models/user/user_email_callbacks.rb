class User < ActiveRecord::Base
  
  #------User email callbacks starts here------------------------------
  #If the user is created by API call or agent create we need to create user_email
  before_validation :create_user_email, on: :create, :if => [:email_available?]

  #If email is updated for user through API or google or if the agent email is updated
  #user_email should be updated
  before_validation :update_user_email, on: :update, if: [:email_id_changed?]

  #To update the verified in user_email, when the active is changed
  after_update :update_verified, :if => [:email_available?, :active_changed?]

  #For user email UI feature. To assign primary email. contact form with multiple emails.
  before_validation :assign_primary_email, on: :create

  #To update user table's email on user create through contact form with multiple emails
  before_validation :update_user_table_email, on: :create, :unless => [:email_available?]

  #To update the primary email on user's update through contact form with multiple emails
  before_validation :set_primary_email, on: :update, unless: [:email_id_changed?]

  #To remove duplicate emails. needed only for contact form with multiple emails
  before_validation :remove_duplicate_emails

  #Sanity check. Not enforced in production and test
  #after_commit :verify_details_on_create, on: :create
  #after_commit :verify_details_on_update, on: :update

  #------User email callbacks ends here------------------------------

  before_update :make_inactive, if: -> { email_id_changed? && !@keep_user_active }
  before_update :make_agent_active, if: -> { email_id_changed? && @keep_user_active && freshid_enabled_and_agent? }
  after_commit :send_activation_email, on: :update, :if => [:email_updated?]

  def send_activation_email
    self.deliver_activation_instructions!(account.main_portal,false) if self.email.present? && !self.primary_email.verified? && freshid_disabled_or_customer? && !self.agent_deleted_forever?
  end

  private

  def verify_details
    unless ["production", "test"].include?(Rails.env)
      self.reload

      if email_available?
        ue_length = (self.user_emails.select(&:primary_role).length == 1) if self.user_emails.present?
        raise error_text unless (self.user_emails.present? and self.email.present? and self.email == self.primary_email.email and ue_length)
      end

      if self[:email].blank?
        raise error_text if self.user_emails.present?
      end
    end
  end
  alias :verify_details_on_create :verify_details
  alias :verify_details_on_update :verify_details

  def error_text
    %(Record error ::: email : #{self.email}, active : #{self.active}, 
      primary_email : #{self.primary_email.inspect}, 
      user_emails : #{self.user_emails.inspect},
      caller: #{caller.inspect})
  end

  def make_inactive
    self.active = self.primary_email.verified? if self.primary_email
    true
  end

  def assign_primary_email
    if primary_email.blank? and self.user_emails.present?
      self.user_emails.first.primary_role = true if self.user_emails.select(&:primary_role?).empty?
      self.primary_email = self.user_emails.select(&:primary_role?).first
    end
  end

  def set_primary_email
    if self.user_emails.present?
      available_emails = self.user_emails.reject(&:marked_for_destruction?)
      if available_emails.present?
        current_primary = available_emails.detect(&:primary_role?) || available_emails.first
        if primary_email
          reset_primary_email(current_primary.id) if current_primary.email != primary_email.email
        else
          current_primary.primary_role = true
          #self.primary_email = current_primary
        end
        self.email = current_primary.email
      else
        self.primary_email = nil
        self.email = nil
      end
    end
  end

  def create_user_email
    # for user email
    build_primary_email({:email => self[:email], :primary_role => true, :user => self, :verified => active, :account => self.account}) if self.user_emails.empty? && self.primary_email.blank?
  end

  def update_user_email
    # for user email
    if primary_email
      if email_available?
        self.primary_email.email = self[:email]
        self.primary_email.verified = false
        true
      else
        self.primary_email.mark_for_destruction
      end
    else
      build_primary_email({:email => self[:email], :primary_role => true, :verified => active, :account_id => account.id}) if email_available?
    end
  end

  def update_verified
    UserEmail.where(user_id: self.id).update_all(verified: self.active)
  end

  def update_user_table_email
    self[:email] = ((primary_email.present? and !primary_email.marked_for_destruction?) ? primary_email.email : nil)
  end

  def user_email_absent?
    (self.primary_email.blank? or primary_changed.present?)
  end

  def primary_changed
    self.user_emails.select{|x| (x.email_changed? or x.marked_for_destruction?) and x.primary_role?}
  end

  def remove_duplicate_emails
    email_array = []
    self.user_emails.select(&:new_record?).each do |ue|
      ue.delete if email_array.include?(ue.email)
      email_array << ue.email
    end
  end

  def email_available?
    self[:email].present?
  end

  def make_agent_active
    self.active = true if self.primary_email
  end
end

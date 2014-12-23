class User < ActiveRecord::Base
  
  #next validations are replaced with :on => :create/:update for rails 3
  before_validation :create_user_email, on: :create, :if => [:email_available?, :user_emails_migrated?]
  before_validation :update_user_email, on: :update, :if => [:email_changed?, :user_emails_migrated?]
  after_update :update_verified, :if => [:email_available?, :active_changed?, :user_emails_migrated?]

  #For user email UI feature  
  before_validation :assign_primary_email, on: :create, :if => :has_contact_merge?
  before_validation :update_user_table_email, on: :update, :if => :has_contact_merge?

  before_validation :set_primary_email, on: :update, :if => [:has_contact_merge?]

  # before_save :remove_duplicate_emails, :if => :has_contact_merge?

  #user email related callback changes for user
  before_update :make_inactive, :if => :email_changed?
  after_update :drop_authorization , :if => [:email_changed?, :no_multiple_user_emails]
  after_commit :send_activation_email, on: :update, :if => [:email_updated?]  

  after_commit :verify_details_on_create, on: :create
  after_commit :verify_details_on_update, on: :update

  def drop_authorization
    authorizations.each do |auth|
      auth.destroy
    end
  end

  def send_activation_email
    self.deliver_activation_instructions!(account.main_portal,false) if self.email.present? and ((has_contact_merge? and !self.primary_email.verified?) or no_contact_merge)
  end

  private

  def verify_details
    unless Rails.env.production?
      self.reload
      if user_emails_migrated? and email_available? and no_contact_merge
        raise error_text unless (self.primary_email.present? and (self.email == self.primary_email.email and self.active == self.primary_email.verified))
      end

      if has_contact_merge? and email_available?
        ue_length = (self.user_emails.select(&:primary_role).length == 1) if self.user_emails.present?
        raise error_text unless (self.user_emails.present? and self.email.present? and self.email == self.primary_email.email and ue_length)
      end

      if has_contact_merge? and self[:email].blank?
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
    if has_contact_merge?
      self.active = self.primary_email.verified? if self.primary_email
    else
      self.active = false
    end
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
          self.primary_email = current_primary
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
    build_primary_email({:email => self[:email], :primary_role => true, :verified => active, :account_id => account.id}) if self.user_emails.empty?
  end

  def update_user_email
    # for user email
    if primary_email
      if email_available?
        self.primary_email.email = self[:email]
      else
        self.primary_email.mark_for_destruction
      end
    else
      build_primary_email({:email => self[:email], :primary_role => true, :verified => active, :account_id => account.id}) if email_available?
    end
  end

  def update_verified
    self.primary_email.verified = self.active
  end

  def update_user_table_email
    self[:email] = ((primary_email.present? and !primary_email.marked_for_destruction?) ? primary_email.email : nil)
  end

  def user_email_absent?
    (self.primary_email.blank? or primary_changed.present?)
  end

  def primary_changed #will happen only with contact_merge_ui
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

    #feature checks
    def user_emails_migrated?
      # for user email delta
      self.account.user_emails_migrated?
    end

    def no_multiple_user_emails
      !has_multiple_user_emails?
    end

    def has_multiple_user_emails?
      self.account.features_included?(:multiple_user_emails) 
    end

    def no_contact_merge
      !has_contact_merge?
    end

    def has_contact_merge?
      self.account.features_included?(:contact_merge_ui)
    end

end
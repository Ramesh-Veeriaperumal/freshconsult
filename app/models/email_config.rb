class EmailConfig < ActiveRecord::Base
  belongs_to :account
  belongs_to :group, :foreign_key =>'group_id' #?!?!?! Not a literal belonging in true ER sense.
  
  #accepts_nested_attributes_for :group
  attr_accessible :to_email, :reply_email, :group_id, :primary_role
  
  validates_presence_of :to_email, :reply_email
  validates_uniqueness_of :to_email, :scope => :account_id
  validates_uniqueness_of :activator_token, :allow_nil => true
  
  before_create :set_activator_token
  after_save :deliver_email_activation
  before_update :reset_activator_token
  
  def deliver_verification_email
    set_activator_token
    save
  end
  
  protected
    def set_activator_token
      (self.active = true) and return if reply_email.downcase.ends_with?("@#{account.full_domain.downcase}")
      
      self.active = false
      self.activator_token = Digest::MD5.hexdigest(Helpdesk::SECRET_1 + reply_email + Time.now.to_f.to_s).downcase
      @need_activation = true #Using a flag #$%@&@%
    end
  
    def deliver_email_activation
      EmailConfigNotifier.send_later(:deliver_activation_instructions, self) if @need_activation
    end

    def reset_activator_token
      old_config = EmailConfig.find id
      set_activator_token unless old_config.reply_email == reply_email
    end
end

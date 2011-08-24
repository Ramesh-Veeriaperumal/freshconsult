class EmailConfig < ActiveRecord::Base
  belongs_to :account
  belongs_to :group, :foreign_key =>'group_id' #?!?!?! Not a literal belonging in true ER sense.
  has_one :portal, :foreign_key => 'product_id', :dependent => :destroy
  has_many :twitter_handles, :foreign_key => 'product_id', :class_name => 'Social::TwitterHandle', 
    :dependent => :destroy


  attr_protected :account_id, :active
  attr_accessor :enable_portal
  
  #To do - Validation for 'name'
  validates_presence_of :to_email, :reply_email
  validates_uniqueness_of :reply_email, :scope => :account_id
  #validates_uniqueness_of :to_email, :scope => :account_id #Since it is auto-generated based
  #on reply email, it's uniqueness is implicit unless we screw up the auto-generation
  #algorithm
  validates_uniqueness_of :activator_token, :allow_nil => true
  
  before_create :set_activator_token
  after_save :deliver_email_activation
  before_update :reset_activator_token
  
  def enable_portal=(p_str)
    @enable_portal = p_str
  end
  
  def enable_portal
    @enable_portal ||= (portal && !portal.new_record?)? '1' : '0'
  end
  
  def portal_enabled?
    enable_portal.eql? '1'
  end
  
  def portal_attributes=(pt_attr)
    unless portal
      if portal_enabled?
        build_portal
        portal.account_id = account_id
        portal.attributes = pt_attr
      end
      return
    end
    
    portal.update_attributes(pt_attr) and return if portal_enabled?
    portal.destroy
  end
  
  def active?
    active
  end
  
  def friendly_email
    active? ? "#{name} <#{reply_email}>" : "support@#{account.full_domain}"
  end
  
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

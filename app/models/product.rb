class Product < ActiveRecord::Base
  
  include CRM::TotangoModulesAndActions 

  before_destroy :remove_primary_email_config_role

  after_create :notify_totango

  belongs_to :account
  has_one    :portal               , :dependent => :destroy
  has_many   :email_configs        , :dependent => :nullify, :order => "primary_role desc"
  has_one    :primary_email_config , :class_name => 'EmailConfig', :conditions => { :primary_role => true }
  has_many   :twitter_handles      , :class_name => 'Social::TwitterHandle', :dependent => :nullify
  has_many   :facebook_pages       , :class_name => 'Social::FacebookPage' , :dependent => :nullify

  attr_protected :account_id
  
  attr_accessor :enable_portal

  accepts_nested_attributes_for :email_configs, :allow_destroy => true 

  delegate :portal_url, :to => :portal, :allow_nil => true 
  delegate :name, :to => :portal, :prefix => true, :allow_nil => true 

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

  def friendly_email
    primary_email_config.friendly_email
  end

  private

    def remove_primary_email_config_role
      primary_email_config.update_attribute(:primary_role, false)
    end

    def notify_totango
      Resque::enqueue(CRM::Totango::SendUserAction, 
                                        account.id, 
                                        account.account_admin.email, 
                                        totango_activity(:multiple_products))
    end
end

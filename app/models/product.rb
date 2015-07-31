class Product < ActiveRecord::Base
  
  self.primary_key = :id
  include Cache::Memcache::Product

  before_destroy :remove_primary_email_config_role
  validates_uniqueness_of :name , :case_sensitive => false, :scope => :account_id
  xss_sanitize :only => [:name, :description], :plain_sanitizer => [:name, :description]

  after_create :create_chat_widget

  after_commit :clear_cache
  after_update :widget_update

  belongs_to_account
  has_one    :portal               , :dependent => :destroy
  has_one    :chat_widget          , :dependent => :destroy
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
    @enable_portal = true
  end
  
  def portal_enabled?
    @enable_portal || !(portal.blank? || portal.new_record?)
  end
  
  def portal_attributes=(pt_attr) # Possible dead code
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


   def widget_update

    if account.features?(:chat) && name_changed?
       chat_widget.update_attributes(:name => name)
        #####
        # Updating name in widgets table of Freshchat DB.
        #####
        Rails.logger.debug " Sending the Product Data to FreshChat through Resque"
        Resque.enqueue(Workers::Livechat, { :worker_method => "update_widget", 
                                             :siteId => account.chat_setting.display_id,
                                             :widget_id => chat_widget.widget_id,
                                             :attributes => { :name => name}
                                            })
      end
   end

    def create_chat_widget
      if account.features?(:chat)
        chat_setting = account.chat_setting
        build_chat_widget
        chat_widget.account_id = account_id
        chat_widget.chat_setting_id = chat_setting.id
        chat_widget.main_widget = false
        chat_widget.active = false
        chat_widget.show_on_portal = false
        chat_widget.portal_login_required = false
        chat_widget.name = name
        chat_widget.save
      end
    end
end

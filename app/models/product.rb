class Product < ActiveRecord::Base
  
  self.primary_key = :id
  include Cache::Memcache::Product
  include Cache::FragmentCache::Base
  include Cache::Memcache::Dashboard::Custom::CacheData

  concerned_with :presenter

  publishable on: [:create, :update, :destroy]

  before_destroy :remove_primary_email_config_role,:save_deleted_product_info
  clear_memcache [TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT]

  validates_uniqueness_of :name , :case_sensitive => false, :scope => :account_id
  xss_sanitize :only => [:name, :description], :plain_sanitize => [:name, :description]

  after_create :create_chat_widget

  before_save :create_model_changes, on: :update


  after_commit :clear_cache
  after_update :widget_update
  after_commit ->(obj) { obj.clear_fragment_caches } , on: :create
  after_commit ->(obj) { obj.clear_fragment_caches } , on: :destroy
  after_commit :clear_fragment_caches, on: :update, :if => :pdt_name_changed?
  after_commit :unset_product_field, :update_dashboard_widgets, :update_help_widgets, on: :destroy 

  belongs_to_account
  has_one    :portal               , :dependent => :destroy
  has_one    :chat_widget          , :dependent => :destroy
  has_many   :email_configs        , :dependent => :nullify, :order => "primary_role desc"
  has_one    :primary_email_config , :class_name => 'EmailConfig', :conditions => { :primary_role => true }
  has_many   :twitter_handles      , :class_name => 'Social::TwitterHandle', :dependent => :nullify
  has_many   :facebook_pages       , :class_name => 'Social::FacebookPage' , :dependent => :nullify
  has_many   :ecommerce_accounts   , :class_name => 'Ecommerce::Account', :dependent => :nullify
  has_many   :help_widgets
  has_one    :bot                  , class_name: 'Bot', dependent: :destroy

  scope :trimmed, -> { select([:'products.id', :'products.name']) }

  swindle :basic_info,
          attrs: %i[name]

  attr_protected :account_id

  attr_accessor :enable_portal

  accepts_nested_attributes_for :email_configs, :allow_destroy => true 

  delegate :portal_url, :to => :portal, :allow_nil => true 
  delegate :name, :to => :portal, :prefix => true, :allow_nil => true 

  def unset_product_field
    #This is done to ensure that required field is marked false on deletion of last multi product.
    #Ticket creation through api might break, if req field is set to true.
    acc = Account.current
    acc.ticket_fields_with_nested_fields.find_by_name(:product).update_attributes({required: "false",required_for_closure: "false"}) if acc.products_from_cache.empty?
  end

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

  def bot_info
    product_bot_info = { name: name, portal_enabled: portal.present? }
    product_bot_info = portal.bot_info.merge!(product_bot_info) if portal
    product_bot_info
  end

  def update_help_widgets # To trigger callbacks
    return unless account.help_widget_enabled?
    help_widgets.each do |h|
      h.update_attributes(:product_id => nil)
    end
  end

  private

    def remove_primary_email_config_role
      primary_email_config.update_attribute(:primary_role, false)
    end

    def save_deleted_product_info
      @deleted_model_info = central_publish_payload
    end

    def create_model_changes
      @model_changes = self.changes.to_hash
      @model_changes.symbolize_keys!
    end

    def update_dashboard_widgets
      # Updates dashboard widgets with product binding
      Helpdesk::DeactivateProductWidgets.perform_async({ product_id: id })
    end

   def widget_update

    if account.features?(:chat) && name_changed?
       chat_widget.update_attributes(:name => name)
        #####
        # Updating name in widgets table of Freshchat DB.
        #####
        Rails.logger.debug " Sending the Product Data to FreshChat through Resque"
        LivechatWorker.perform_async({ :worker_method => "update_widget",
                                             :siteId => account.chat_setting.site_id,
                                             :widget_id => chat_widget.widget_id,
                                             :attributes => { :name => name}
                                            })
      end
   end

    def update_dashboard_widgets
      # Updates dashboard widgets with product binding
      Helpdesk::DeactivateProductWidgets.perform_async({ product_id: id })
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

    def pdt_name_changed?
      self.previous_changes.keys.include?('name')
    end
end

class Portal < ActiveRecord::Base
  include ActionController::UrlWriter

  serialize :preferences, Hash
  
  validates_uniqueness_of :portal_url, :allow_blank => true, :allow_nil => true
  #validates_presence_of :product_id
  
  has_one :logo,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions =>  [' description = ? ', 'logo' ],
    :dependent => :destroy
  
  has_one :fav_icon,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => [' description = ?', 'fav_icon' ], 
    :dependent => :destroy
  
  has_one :template, :class_name => 'Portal::Template'

  belongs_to :account
  belongs_to :product, :class_name => 'EmailConfig'
  
  #Again, the below two are not in literal 'ER belongs_to', just a one-to-one mapping.
  belongs_to :solution_category, :class_name => 'Solution::Category',
              :foreign_key => 'solution_category_id'
  belongs_to :forum_category
  
  #accepts_nested_attributes_for :logo, :fav_icon
  
  def logo_attributes=(icon_attr)
    handle_icon 'logo', icon_attr
  end
  
  def fav_icon_attributes=(icon_attr)
    handle_icon 'fav_icon', icon_attr
  end

  def fav_icon_url
    fav_icon.nil? ? '/images/favicon.ico' : fav_icon.content.url
  end
  
  #Helpers for views
  def main_portal?
    product.primary_role
  end
  
  def solution_categories
    main_portal? ? account.solution_categories : (solution_category ? [solution_category] : [])
  end
  
  def forum_categories
    main_portal? ? account.forum_categories : (forum_category ? [forum_category] : [])
  end
  
  #Yeah.. It is ugly.
  def ticket_fields(additional_scope = :all)
    filter_fields account.ticket_fields.send(additional_scope)
  end
  
  def customer_editable_ticket_fields
    filter_fields account.ticket_fields.customer_editable
  end

  def layout
    self.template.layout    
  end
  
  def to_liquid
    PortalDrop.new self
  end
  
  def portal_login_path
    login_path(:host => portal_url)
  end
  
  def portal_logout_path
    logout_path(:host => portal_url)
  end
  
  def signup_path
    new_support_registration_path(:host => portal_url)
  end
  
  def new_ticket_path
    new_support_ticket_path(:host => portal_url)
  end 

  def host
    portal_url.blank? ? account.full_domain : portal_url
  end
  
  private
    def handle_icon(icon_field, icon_attr)
      unless send(icon_field)
        icon = send("build_#{icon_field}")
        icon.description = icon_field
        icon.content = icon_attr[:content]
        icon.account_id = account_id
      else
        send(icon_field).update_attributes(icon_attr)
      end
    end
    
    def filter_fields(f_list)
      to_ret = []
      checks = { 'product' => (main_portal? && !account.products.empty?) }

      f_list.each { |field| to_ret.push(field) if checks.fetch(field.name, true) }
      to_ret
    end
  
end

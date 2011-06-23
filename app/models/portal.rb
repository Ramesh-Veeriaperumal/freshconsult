class Portal < ActiveRecord::Base
  serialize :preferences, Hash
  
  validates_uniqueness_of :portal_url, :allow_blank => true, :allow_nil => true
  #validates_presence_of :product_id
  
  has_one :logo,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    #:conditions => ['description = ?', 'logo' ],
    :conditions => { :description => 'logo' },
    :dependent => :destroy
  
  has_one :fav_icon,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'fav_icon' ],
    :dependent => :destroy

  belongs_to :account
  belongs_to :product, :class_name => 'EmailConfig'
  
  #Again, the below two are not in literal 'ER belongs_to', just a one-to-one mapping.
  belongs_to :solution_category, :class_name => 'Solution::Category',
              :foreign_key => 'solution_category_id'
  belongs_to :forum_category
  
  #accepts_nested_attributes_for :logo, :fav_icon
  
  def logo_attributes=(icon_attr)
    self.logo = Helpdesk::Attachment.new
    logo.description = "logo"
    logo.content = icon_attr[:content]
  end
  
  def fav_icon_attributes=(icon_attr)
    self.fav_icon = Helpdesk::Attachment.new
    fav_icon.description = "fav_icon"
    fav_icon.content = icon_attr[:content]
  end
  
  before_create :populate_account_id
  
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
  
  protected
    def populate_account_id
      logo.account_id = account_id if logo
      fav_icon.account_id = account_id if fav_icon
    end
end

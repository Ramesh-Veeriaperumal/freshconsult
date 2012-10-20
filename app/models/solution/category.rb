require RAILS_ROOT+'/app/models/solution/folder.rb'
#In the gamification environment, Solution::Folder::VISIBILITY_KEYS_BY_TOKEN was not
#accessible. It may be due to some screw up with the order of class loading.
#So, temporarily put the 'require' here. Shan

class Solution::Category < ActiveRecord::Base

  set_table_name "solution_categories"
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id
  
   belongs_to :account
   
   has_many :folders, :class_name =>'Solution::Folder' , :dependent => :destroy, :order => "position"
   has_many :public_folders, :class_name =>'Solution::Folder' ,  :order => "position", 
            :conditions => [" solution_folders.visibility = ? ",Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]]
   has_many :user_folders, :class_name =>'Solution::Folder' , :order => "position", 
            :conditions => [" solution_folders.visibility in (?,?) ",
            Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone],Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
   
   acts_as_list :scope => :account
   
   attr_accessible  :name,:description,:import_id, :is_default
   
   named_scope :customer_categories, {:conditions => {:is_default=>false}}     

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end

  def self.folder_names(account)
    account.solution_categories.map { |category| 
      [ category.name, category.folders.map {|folder| [folder.id, folder.name] } ]
    }
  end
  
  def self.get_default_categories_visibility(user)
    user.customer? ? {:is_default=>false} : {}
  end
   
end

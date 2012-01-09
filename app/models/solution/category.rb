class Solution::Category < ActiveRecord::Base
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id
  
   belongs_to :account
   set_table_name "solution_categories"
   
   has_many :folders, :class_name =>'Solution::Folder' , :dependent => :destroy, :order => "position" 
   
   acts_as_list :scope => :account
   
   attr_accessible  :name,:description,:import_id
   
   def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end
   
end

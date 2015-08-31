module Solution::LanguageAssociations
  extend ActiveSupport::Concern
  
  included do |base|
    base_class = base.name.chomp('Meta')
    base_name = base_class.gsub("Solution::", '').downcase
    Language.all.each do |lang|
      base.has_one :"#{lang.to_key}_#{base_name}",
        :conditions => { language_id: lang.id },
        :class_name => base_class, 
        :foreign_key => :parent_id, 
        :autosave => true

    end
    
    base.has_one :"primary_#{base_name}",
      :conditions => proc { { language_id: Language.for_current_account.id } },
      :class_name => base_class, 
      :foreign_key => :parent_id, 
      :autosave => true
      
    delegate :name, :description, :title, :to => :"primary_#{base_name}"
  end
  
end
module Solution::LanguageAssociations
  extend ActiveSupport::Concern
  
  included do |base|
    base.include Binarize
    base::BINARIZE_COLUMNS.each do |col|
      base.binarize col, :flags => Language.all_keys
    end
    base_class = base.name.chomp('Meta')
    base_name = base_class.gsub("Solution::", '').downcase
    table_name = base.table_name.to_sym
    Language.all.each do |lang|
      base.has_one :"#{lang.to_key}_#{base_name}",
        :conditions => { language_id: lang.id },
        :class_name => base_class, 
        :foreign_key => :parent_id, 
        :readonly => false, 
        :autosave => true,
        :inverse_of => table_name
    end
    
    base.has_one :"primary_#{base_name}",
      :conditions => proc { { language_id: Language.for_current_account.id } },
      :class_name => base_class, 
      :foreign_key => :parent_id, 
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name
      
    delegate :name, :description, :title, :to => :"primary_#{base_name}"
    
    def self.translation_associations
      base_name = self.name.chomp('Meta').gsub("Solution::", '').downcase
      (['primary'] | Account.current.applicable_languages).collect(&:to_sym).collect {|s| :"#{s}_#{base_name}"}
    end

    def self.short_name
      self.name.chomp('Meta').gsub("Solution::", '').downcase
    end
    
    scope :include_translations, lambda {
      includes(translation_associations)
    }

    base::BINARIZE_COLUMNS.each do |col|
      define_method "any_supported_#{col}?" do
        Account.current.applicable_languages.each do |lan|
          return true if self.send("#{lan}_#{col}?")
        end
        return false
      end

      define_method "all_supported_#{col}?" do
        Account.current.applicable_languages.each do |lan|
          return false unless self.send("#{lan}_#{col}?")
        end
        true
      end

      define_method "supported_in_#{col}?" do
        send("in_#{col}") & Account.current.applicable_languages.map(&:to_key)
      end
    end
  end
  
end
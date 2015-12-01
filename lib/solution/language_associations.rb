module Solution::LanguageAssociations
  extend ActiveSupport::Concern
  
  included do |base|
    base.include Binarize
    base::BINARIZE_COLUMNS.each do |col|
      base.binarize col, :flags => Language.all_keys
    end
    base_class = base.name.chomp('Meta')
    base_name = base_class.gsub("Solution::", '').downcase
    base_class_table_name = base_class.constantize.table_name
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

    has_many :versions,
      :class_name => base_class,
      :foreign_key => :parent_id,
      :conditions => proc { ["`#{base_class_table_name}`.language_id in (?)", Account.current.all_language_ids] }
    
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

      define_method "#{col}_languages" do
        languages = []
        Account.current.supported_languages.each do |lan|
          languages << Language.find_by_code(lan) if self.send("#{lan.gsub('-','_').downcase}_#{col}?")
        end
        languages
      end
    end
  end
  
end
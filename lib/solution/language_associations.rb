module Solution::LanguageAssociations
  extend ActiveSupport::Concern
  include Solution::ApiDelegator

  included do |base|
    base.include Binarize
    base::BINARIZE_COLUMNS.each do |col|
      base.binarize col, :flags => Language.all_keys
    end
    base_class = base.name.chomp('Meta')
    base_class_table_name = base_class.constantize.table_name
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

    base.has_one :"current_#{base_name}",
      :conditions => proc { { language_id: Language.for_current_account.id } },
      :class_name => base_class,
      :foreign_key => :parent_id,
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name
      
    base.has_one :"primary_#{base_name}",
      :conditions => proc { { language_id: Language.for_current_account.id } },
      :class_name => base_class,
      :foreign_key => :parent_id, 
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name
    
    delegation_title = base_class.constantize.column_names.include?("name") ? :name : :title

    delegate delegation_title, :description, :to => :"primary_#{base_name}"
    
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
    
    scope :current, lambda {
      {
        :joins => :"current_#{base_name}",
        :select => ["`#{base_class_table_name}`.*,`#{base_class_table_name}`.id as current_child_id, `#{table_name}`.*"]
      }
    }

    default_scope lambda { Language.current? ? current : unscoped }
        
    after_find :handle_date_time

    base::BINARIZE_COLUMNS.each do |col|
      define_method "any_supported_#{col}?" do
        Account.current.all_language_objects.map(&:to_key).each do |lan|
          return true if self.send("#{lan}_#{col}?")
        end
        return false
      end

      define_method "all_supported_#{col}?" do
        Account.current.all_language_objects.map(&:to_key).each do |lan|
          return false unless self.send("#{lan}_#{col}?")
        end
        true
      end

      define_method "supported_in_#{col}?" do
        send("in_#{col}") & Account.current.all_language_objects.map(&:to_key)
      end

      define_method "primary_#{col}?" do
        send("#{Language.for_current_account.to_key}_#{col}?")
      end

      define_method "current_#{col}?" do
        send("#{Language.current.to_key}_#{col}?")
      end
    end

    base::BINARIZE_COLUMNS.each do |meth_name|
      define_method(meth_name) do
        return self[meth_name] if self[meth_name]
        columns = base::BINARIZE_COLUMNS.select{|c| self[c].blank?}
        include_class = columns.include?(:draft_present) ? [:draft] : []
        self.children.includes(include_class).each do |child|
          columns.each do |col|
            compute_assign_binarize(col, child)
          end
        end
        self[meth_name]
      end
    end

    def compute_assign_binarize(col, child)
      val = self.read_attribute(col).to_i || 0
      val = val | flag_mapping(col, child.language_key) if child.send("#{col}?")
      self[col] = val
    end
    
    def method_missing(method, *args, &block)
  		begin
  			super
  		rescue NoMethodError => e
  			Rails.logger.debug "#{self.class.name} :: method_missing :: args is #{args.inspect} and method:: #{method}"
  			args = args.first if args.present? && args.is_a?(Array)
        child_assoc = self.class.name.chomp('Meta').gsub("Solution::", '').downcase
  			return ((args.present? || args.nil?) ? self.send("current_#{child_assoc}").send(method, args) :
              self.send("current_#{child_assoc}").send(method))
  			raise e
  		end
    end
      
    def child_class_name
      self.class.name.chomp('Meta')
    end
    
    def handle_date_time
      self.attributes.slice(*child_class_name.constantize.columns_hash.select {|k,v| 
        v.type == :datetime}.keys).each do |time_column,value|
        self[time_column] = Time.zone.parse(value.to_s)
      end
    end
  end
end

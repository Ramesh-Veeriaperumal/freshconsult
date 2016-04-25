module Solution::LanguageAssociations
  extend ActiveSupport::Concern
  include Solution::ApiDelegator

  included do |base|
    base.include Binarize
    base::BINARIZE_COLUMNS.each do |col|
      base.binarize col, :flags => Language.all_keys
    end
    child_class = base.name.chomp('Meta')
    child_class_table_name = child_class.constantize.table_name
    child_name = child_class.gsub("Solution::", '').downcase
    table_name = base.table_name.to_sym
    
    Language.all.each do |lang|
      base.has_one :"#{lang.to_key}_#{child_name}",
        :conditions => proc { { language_id: lang.id, 
          account_id: Account.current.id } },
        :class_name => child_class, 
        :foreign_key => :parent_id, 
        :readonly => false, 
        :autosave => true,
        :inverse_of => table_name
    end

    base.has_one :"current_#{child_name}",
      :conditions => proc { { 
            language_id: (Language.current? ? Language.current.id : Language.for_current_account.id), 
            account_id: Account.current.id } },
      :class_name => child_class,
      :foreign_key => :parent_id,
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name
      
    base.has_one :"primary_#{child_name}",
      :conditions => proc { { language_id: Language.for_current_account.id, 
        account_id: Account.current.id } },
      :class_name => child_class,
      :foreign_key => :parent_id, 
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name
      
    delegation_title = child_class.constantize.table_exists? && child_class.constantize.column_names.include?("name") ? :name : :title

    define_method delegation_title do
      delegation_assoc = Language.current? ? :"current_#{child_name}" : :"primary_#{child_name}"
      self.attributes[delegation_title.to_s] || send(delegation_assoc).send(delegation_title)
    end

    def self.translation_associations
      child_name = self.name.chomp('Meta').gsub("Solution::", '').downcase
      (['primary'] | Account.current.applicable_languages).collect(&:to_sym).collect {|s| :"#{s}_#{child_name}"}
    end

    def self.short_name
      self.name.chomp('Meta').gsub("Solution::", '').downcase
    end
    
    def self.child_class
      self.name.chomp('Meta').constantize
    end
    
    scope :include_translations, lambda {
      includes(translation_associations)
    }
    
    scope :current, lambda {
      {
        :joins => :"current_#{child_name}",
        :select => [ select_string_for_query ]
      }
    }

    def self.unscoped_find(id)
      unscoped.find_by_id_and_account_id(id, Account.current.id)
    end
    
    def self.select_string_for_query
      select_string = "`#{child_class.table_name}`.*"
      child_class::SELECT_ATTRIBUTES.each do |attribute|
        select_string += ", `#{child_class.table_name}`.#{attribute} as current_child_#{attribute}"
      end
      select_string += ", `#{table_name}`.*"
      select_string
    end

    default_scope lambda { Language.current? ? current : Account.current && where(:account_id => Account.current.id) }
        
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

    def portal_available_versions
      language_keys = in_available & Account.current.all_portal_language_objects.map(&:to_key)
      language_keys.map{ |l| Language.find_by_key(l) }
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

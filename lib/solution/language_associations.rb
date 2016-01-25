module Solution::LanguageAssociations
  extend ActiveSupport::Concern

  included do |base|
    base_class = base.name.chomp('Meta')
    base_class_table_name = base_class.constantize.table_name
    base_name = base_class.gsub("Solution::", '').downcase
    table_name = base.table_name.to_sym

    base.has_one :"current_#{base_name}",
      :conditions => proc {  ["`#{base_class_table_name}`.language_id = ? AND `#{base_class_table_name}`.account_id = ?",
                Language.for_current_account.id, Account.current.id] },
      :class_name => base_class,
      :foreign_key => :parent_id,
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name
      
    base.has_one :"primary_#{base_name}",
      :conditions => proc {  ["`#{base_class_table_name}`.language_id = ? AND `#{base_class_table_name}`.account_id = ?",
                Language.for_current_account.id, Account.current.id] },
      :class_name => base_class,
      :foreign_key => :parent_id, 
      :readonly => false,
      :autosave => true,
      :inverse_of => table_name

    scope :current, lambda {
      {
        :joins => :"current_#{base_name}",
        :select => ["`#{base_class_table_name}`.*,`#{base_class_table_name}`.id as current_child_id, `#{table_name}`.*"]
      }
    }

    default_scope lambda {current}
        
    after_find :handle_date_time
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

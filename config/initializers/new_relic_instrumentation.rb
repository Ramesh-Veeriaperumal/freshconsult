if defined? ActiveRecord
  ActiveRecord::Base.class_eval do
    class << self
      add_method_tracer :search, 'ActiveRecord/#{self.name}/search'
      add_method_tracer :search, 'ActiveRecord/search', :push_scope => false
      add_method_tracer :search, 'ActiveRecord/all', :push_scope => false

      add_method_tracer :search_count, 'ActiveRecord/#{self.name}/search_count'
      add_method_tracer :search_count, 'ActiveRecord/search_count', :push_scope => false
      add_method_tracer :search_count, 'ActiveRecord/all', :push_scope => false
    end
  end
end
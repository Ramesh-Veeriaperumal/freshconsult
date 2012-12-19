module ThinkingSphinx
  module ActiveRecord
    module ClassMethods
      def add_sphinx_callbacks_and_extend(delta = false)
      RAILS_DEFAULT_LOGGER.debug "$$$$$$$$$$$$$$$$$$$ Came for Delta add_sphinx_callbacks_and_extend"
      unless indexed_by_sphinx?
        after_destroy :toggle_deleted
          
        include ThinkingSphinx::ActiveRecord::AttributeUpdates
      end
        
      if delta && !delta_indexed_by_sphinx?
        include ThinkingSphinx::ActiveRecord::Delta
          
        before_save   :toggle_delta
        after_commit_on_update  :index_delta
      end
    end
    end
  end
end


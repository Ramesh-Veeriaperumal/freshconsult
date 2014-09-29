module ArExtensions
  def self.included(base)
    warn "Warning! ArExtensions included" unless Rails.version.to_i < 3
    base.class_eval  do
      after_create :persist_previous_changes
      after_update :persist_previous_changes

      def previous_changes
        @custom_previous_changes || {}
      end

      def reload
        @custom_previous_changes = {}
        super
      end

      private
        def persist_previous_changes
          @custom_previous_changes = changes
        end  
    end

  end
end

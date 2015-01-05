module Stores
  module CustomFieldChoice
    module ActiveRecordMethods

      def stores_custom_field_choice args = {}
        validates_presence_of :value
        
        belongs_to :custom_field, :class_name => args[:custom_field_class],
                   :foreign_key => args[:custom_field_id]#:pickable, :polymorphic => true
        
        attr_accessible :value, :position
      end

    end
  end
end
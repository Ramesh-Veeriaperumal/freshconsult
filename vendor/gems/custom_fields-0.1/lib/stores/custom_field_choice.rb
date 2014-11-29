module Stores
  module CustomFieldChoice
    module ActiveRecordMethods

      def stores_custom_field_choice args = {}
        validates_presence_of :value
        validates_uniqueness_of :value, :scope => [:account_id, args[:custom_field_id]]
        
        belongs_to :custom_field, :class_name => args[:custom_field_class],
                   :foreign_key => args[:custom_field_id]#:pickable, :polymorphic => true
        
        acts_as_list
      end

    end
  end
end
module Inherits
  module CustomField
    module ActiveRecordMethods

      include CustomFields::Constants

      def inherits_custom_field args = {}
        const_set('CUSTOM_FORM_METHOD', args[:custom_form_method])
        const_set('FIELD_DATA_CLASS', args[:field_data_class])
        const_set('CUSTOM_FORM_ID_COLUMN', args[:form_id])

        attr_accessor :action
        attr_protected :account_id, args[:form_id]
        alias_attribute :custom_form_id, args[:form_id]

        belongs_to :custom_form, :class_name => args[:form_class], :foreign_key => args[:form_id] #:flexifield_def
        has_many  :custom_field_choices, :class_name => args[:field_choices_class],
                  :order => :position, :dependent => :destroy #picklist_values

        before_validation     :populate_choices # need to build this once assigned and do autosave like flexifield- next version
        validates_presence_of :name, :column_name, :position #flexifield_alias, flexifield_name, flexifield_order

        acts_as_list # helps in reordering
        # hack.. no better way in Rails 2 - removing from list in builder methods when deleted => true
        before_destroy.reject!{ |callback| callback.method == :remove_from_list } #coz we are doing hard delete only later

        named_scope :custom_fields, :conditions => ["field_type > '#{MAX_DEFAULT_FIELDS}'"]
        named_scope :deleted, :conditions => { :deleted => true }

        include InstanceMethods
        include ApiMethods
        include Inherits::CustomField::Constants
        include Inherits::CustomField::Methods
        include CRUDMethods::InstanceMethods
        extend  CRUDMethods::ClassMethods

      end

    end
  end
end

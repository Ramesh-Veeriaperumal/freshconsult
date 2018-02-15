class DenormalizedFlexifield < ActiveRecord::Base
  
  self.primary_key= :id
  
  include FlexifieldConstants

  belongs_to_account

  belongs_to :flexifield_def
  belongs_to :flexifield

  attr_protected :account_id, :flexifield_id, :flexifield_def_id
  attr_accessor :load_state

  after_initialize :set_default_values, :duplicate_load_state 

  SERIALIZED_COLUMN_MAPPING_BY_DB_COLUMN.keys.each do |db_column|
    serialize db_column
  end

  before_validation :sanitize_serialized_data
  after_commit :duplicate_load_state

  SERIALIZED_COLUMN_MAPPING_BY_ATTRIBUTES.each do |attribute, db_column|
    define_method attribute do
      safe_send(db_column)[attribute]
    end

    define_method "#{attribute}=" do |value|
      if value.present?
        safe_send(db_column)[attribute] = value
      else
        safe_send(db_column).delete(attribute)
      end
    end
  end

  def set_default_values #helps in changes calculation
    CREATED_SERIALIZED_COLUMNS.each do |db_column|
      write_attribute(db_column, {}) if respond_to?(db_column) && safe_send(db_column).nil?
    end
  end

  def duplicate_load_state
    @load_state ||= self.attributes.with_indifferent_access #works as we dont have arrays
    #Marshal.load(Marshal.dump(self.attributes)).with_indifferent_access #for deep cloning #need to check on security issues
  end

  def changes_of_serialized_attributes #can be optimized
    @changes_of_serialized_attributes = {}
    SERIALIZED_COLUMN_MAPPING_BY_DB_COLUMN.each do |db_column, attributes|
      attributes.each do |attribute|
        old_value = self.load_state[attribute]
        new_value = self.safe_send(attribute)
        @changes_of_serialized_attributes[attribute] = [old_value, new_value] if old_value != new_value
      end
    end
    @changes_of_serialized_attributes
  end

  def sanitize_serialized_data #can be optimized
    SERIALIZED_COLUMN_SANITIZATION_METHODS.each do |methods, attributes|
      methods.each do |method_name|
        attributes.each do |attribute|
          safe_send(method_name, attribute)
        end
      end
    end
  end

  def trim_length_of_slt attribute
    send "#{attribute}=", safe_send(attribute).to_s[0..254] if safe_send(attribute).present? #not adding a validation error to mimic SQL behaviour
  end  

  # def convert_to_integer attribute
  #   safe_send("#{attribute}=", safe_send(attribute).to_i) if safe_send(attribute).present?
  # end

  # def convert_to_decimal attribute
  #   safe_send("#{attribute}=", safe_send(attribute).to_f) if safe_send(attribute).present?
  # end

  def attributes_with_deserialization
    attributes_without_deserialization.deep_dup.each_with_object({}) do |(attribute, value), attrs|
      if value.is_a? Hash
        attrs.merge!(value) unless value.blank?
      else
        attrs[attribute] = value
      end
    end
  end

  alias_method_chain :attributes, :deserialization

end

# To change this template, choose Tools | Templates
# and open the template in the editor.

class Flexifield < ActiveRecord::Base
  
  self.primary_key= :id
  
  include FlexifieldConstants

  belongs_to_account

  belongs_to :flexifield_set, :polymorphic => true
  belongs_to :flexifield_def, :include => 'flexifield_def_entries'

  has_one :denormalized_flexifield, :class_name => "DenormalizedFlexifield", :dependent => :destroy
  accepts_nested_attributes_for :denormalized_flexifield
  # xss_terminate

  after_initialize :initialize_denormalized_flexifield

  delegate :to_ff_alias, :to_ff_field,
           :ff_aliases, :non_text_ff_aliases,
           :ff_fields, :non_text_ff_fields, :text_and_number_ff_fields, :text_ff_fields, :to => :flexifield_def

  zero_downtime_migration_methods :methods => {:remove_columns => ["ff_boolean11","ff_boolean12","ff_boolean13","ff_boolean14","ff_boolean15","ff_boolean16","ff_boolean17","ff_boolean18","ff_boolean19","ff_boolean20"] }

  def initialize_denormalized_flexifield
    if Account.current.denormalized_flexifields_enabled? && denormalized_flexifield.nil?
      build_denormalized_flexifield 
    end
  end
  
  def self.flexiblefield_names
    column_names.grep(/ff.+/)
  end
  
  def ff_def
    read_attribute :flexifield_def_id
  end
  
  def ff_def= ff_def_id
    self.flexifield_def_id = ff_def_id
  end
  
  def get_ff_value ff_alias
    ff_field = to_ff_field ff_alias
    if ff_field
      read_ff_attribute ff_field
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end

  def set_ff_value ff_alias, ff_value, ff_field = nil
    ff_field ||= to_ff_field ff_alias
    if ff_field       
      ff_value = nil if ff_value.blank?
      write_ff_attribute ff_field, ff_value
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end
  
  def assign_ff_values args_hash
    unless args_hash.is_a? Hash
      raise ArgumentError, "Method argument must be a hash"
    end
    mapping = Account.current.ticket_field_def.ff_alias_column_mapping
    args_hash.each do |ffalias, ffvalue|
      set_ff_value ffalias, ffvalue, mapping[ffalias]
    end
    # save
  end

  def retrieve_ff_values
    ff_aliases.inject({}) do  |ff_values, ff_alias| 
      ff_values[ff_alias] = (get_ff_value ff_alias)
      ff_values
    end || {}
  end

  def retrieve_ff_values_via_mapping
    Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) do |(aliass, column_name), ff_values|
      ff_values[aliass] = read_ff_attribute(column_name)
    end
  end

  def write_ff_attribute attribute, value
    if self.class.flexiblefield_names.include?(attribute.to_s)
      write_attribute(attribute, value)
    elsif SERIALIZED_ATTRIBUTES.include?(attribute) && denormalized_flexifield.present?
      denormalized_flexifield.send "#{attribute}=", value
    else
      raise ArgumentError, "Trying to write #{attribute} with value #{value}; Field doesnt exist"
    end
  end

  def read_ff_attribute attribute
    if self.class.flexiblefield_names.include?(attribute.to_s)
      read_attribute(attribute)
    elsif SERIALIZED_ATTRIBUTES.include?(attribute) && denormalized_flexifield.present?
      denormalized_flexifield.safe_send(attribute)
    else
      raise ArgumentError, "Trying to read #{attribute}; Field doesnt exist"
    end
  end

  def before_save_changes #to avoid changes being recalculated
    @before_save_changes ||= changes_incl_serialized_attributes 
  end

  def changes_incl_serialized_attributes
    denormalized_flexifield.present? ? changes.merge!(denormalized_flexifield.changes_of_serialized_attributes) : changes
  end

  def attributes_with_denormalized_flexifield
    denormalized_attributes = denormalized_flexifield.present? ? denormalized_flexifield.attributes : {}
    attributes_without_denormalized_flexifield.dup.reverse_merge(denormalized_attributes)
  end

  alias_method_chain :attributes, :denormalized_flexifield

end


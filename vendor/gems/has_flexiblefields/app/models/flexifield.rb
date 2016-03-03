# To change this template, choose Tools | Templates
# and open the template in the editor.

class Flexifield < ActiveRecord::Base
  
  self.primary_key= :id
  
  belongs_to_account

  belongs_to :flexifield_set, :polymorphic => true
  belongs_to :flexifield_def, :include => 'flexifield_def_entries'

  # xss_terminate

  self.primary_key = :id

  
  delegate :to_ff_alias, :to_ff_field,
           :ff_aliases, :non_text_ff_aliases,
           :ff_fields, :non_text_ff_fields, :text_and_number_ff_fields, :to => :flexifield_def
  
  def self.flexiblefield_names
    columns.map(&:name).grep(/ff.+_/)
  end
  
  def self.flexiblefield_names_count
    columns.map(&:name).grep(/ff.+_/).length
  end
  
  def ff_def
    read_attribute :flexifield_def_id
  end
  
  def ff_def= ff_def_id
    self.flexifield_def_id = ff_def_id
    # write_attribute :flexifield_def_id, ff_def_id
    # save
  end
  
  def get_ff_value ff_alias
    ff_field = to_ff_field ff_alias
    if ff_field
      read_attribute ff_field
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end
  
  def set_ff_value ff_alias, ff_value
    ff_field = to_ff_field ff_alias    
    if ff_field       
      ff_value = nil if ff_value.blank?
      write_attribute ff_field, ff_value
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end
  
  def assign_ff_values args_hash
    unless args_hash.is_a? Hash
      raise ArgumentError, "Method argument must be a hash"
    end
    args_hash.each do |ffalias, ffvalue|
      set_ff_value ffalias, ffvalue
    end
    # save
  end

  def retrieve_ff_values
    ff_aliases.inject({}) do  |ff_values, ff_alias| 
      ff_values[ff_alias] = (get_ff_value ff_alias)
      ff_values
    end || {}
  end

  def retrieve_modified_ff_values
    Account.current.ticket_field_def.ff_alias_column_mapping.each_with_object({}) do |(aliass, column_name), ff_values|
      ff_values[aliass] = read_attribute(column_name)
    end
  end

end

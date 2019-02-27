class TicketFieldData < ActiveRecord::Base

  belongs_to_account
  self.table_name =  "ticket_field_data"

  self.primary_key = :id

  belongs_to_account

  belongs_to :flexifield_set, :polymorphic => true
  belongs_to :flexifield_def, :include => 'flexifield_def_entries'
  delegate :to_ff_alias, :to_ff_field, :to_ff_def_entry, :to => :flexifield_def

  ALLOWED_FIELD_TYPES = ['custom_dropdown', 'custom_number', 'custom_checkbox', 'nested_field', 'custom_date']

  def ff_def
    read_attribute :flexifield_def_id
  end

  def ff_def= ff_def_id
    self.flexifield_def_id = ff_def_id
  end

  def get_ff_value ff_alias, field = nil
    field ||= fields_from_cache[ff_alias]
    if ff_def_entry
      process_while_reading field
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end

  def set_ff_value ff_alias, ff_value, field = nil
    field ||= fields_from_cache[ff_alias]
    if field       
      ff_value = nil if ff_value.blank?
      process_while_writing field, ff_value
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end

  def assign_ff_values args_hash
    unless args_hash.is_a? Hash
      raise ArgumentError, "Method argument must be a hash"
    end
    args_hash = args_hash.sort_by do |ff_alias, ff_value|
      field = fields_from_cache[ff_alias]
      field.try(:level).to_i
    end.to_h
    args_hash.each do |ff_alias, ff_value|
      field_from_cache = fields_from_cache[ff_alias]
      set_ff_value ff_alias, ff_value, field_from_cache
    end
    # save
  end

  def retrieve_ff_values
    ff_aliases.inject({}) do  |ff_values, ff_alias| 
      field_from_cache = fields_from_cache[ff_alias]
      ff_values[ff_alias] = (get_ff_value ff_alias, field_from_cache)
      ff_values
    end || {}
  end

  def retrieve_ff_values_via_mapping
    account.ticket_field_def.ff_alias_column_type_mapping.each_with_object({}) do |(aliass, column_name_and_field_type), ff_values|
      ff_values[aliass] = process_while_reading(*column_name_and_field_type)
    end
  end

  def write_ff_attribute attribute, value, field_type
    if self.class.flexiblefield_names.include?(attribute.to_s) && ALLOWED_FIELD_TYPES.include?(field_type)
      write_attribute(attribute, value)
    else
      Rails.logger.info "Trying to write #{attribute} with value #{value}; Field doesnt exist"
    end
  end

  def read_ff_attribute attribute, field_type
    if self.class.flexiblefield_names.include?(attribute.to_s) && ALLOWED_FIELD_TYPES.include?(field_type)
      read_attribute(attribute)
    else
      Rails.logger.info "Trying to read #{attribute}; Field doesnt exist"
    end
  end


  class << self # Class Methods

    def flexiblefield_names
      @flexiblefield_names ||= column_names.grep(/ff.+/)
    end

  end

  private

    def process_while_reading field
      field_type = field.field_type
      ff_value = Time.use_zone('UTC') { read_ff_attribute(field.column_name, field_type) }
      return nil if ff_value.blank?
      value = case field_type
      when 'custom_dropdown', 'nested_field'
        read_transformer.transform(ff_value, field.flexifield_name)
      else
        ff_value
      end
    end

    def process_while_writing field, ff_value
      field_type = field.field_type
      value = case field_type
      when 'custom_dropdown', 'nested_field'
        ff_value.is_a?(Numeric) || ff_value.nil? ? ff_value : write_transformer.transform(ff_value, field.flexifield_name)
      else
        ff_value
      end
      write_ff_attribute(field.column_name, value, field_type)
    end

    def fields_from_cache
      @fields_from_cache ||= account.ticket_fields_from_cache.each_with_object({}) do |field, hash|
        hash[field.name] = field unless field.is_default_field?
      end
    end

    def read_transformer
      @read_transformer ||= Helpdesk::Ticketfields::PicklistValueTransformer::IdToString.new(flexifield_set)
    end

    def write_transformer
      @write_transformer ||= Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new(flexifield_set)
    end
end

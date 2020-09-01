class TicketFieldData < ActiveRecord::Base
  belongs_to_account
  self.table_name =  'ticket_field_data'
  self.primary_key = :id

  belongs_to :flexifield_set, polymorphic: true
  belongs_to :flexifield_def, include: 'flexifield_def_entries'
  delegate :to_ff_alias, :to_ff_field, :to_ff_def_entry, to: :flexifield_def

  before_validation :nested_field_correction

  ALLOWED_FIELD_TYPES = ['custom_dropdown', 'custom_number', 'custom_checkbox', 'nested_field', 'custom_date', 'custom_date_time', 'custom_file'].freeze
  NEW_DROPDOWN_COLUMN_NAMES = column_names.grep(/ffs.+/)[80..249]
  NEW_DROPDOWN_COLUMN_NAMES_SET = Set.new(NEW_DROPDOWN_COLUMN_NAMES)
  NEW_CHECKBOX_COLUMN_NAMES = column_names.grep(/ff_boolean.+/)[10..30]
  NEW_CHECKBOX_COLUMN_NAMES_SET = Set.new(NEW_CHECKBOX_COLUMN_NAMES)
  NEW_DATE_FIELD_COLUMN_NAMES = column_names.grep(/ff_date.+/)[10..30]
  NEW_DATE_FIELD_COLUMN_NAMES_SET = Set.new(NEW_DATE_FIELD_COLUMN_NAMES)
  NEW_NUMBER_FIELD_COLUMN_NAMES = column_names.grep(/ff_int.+/)[20..30]
  NEW_NUMBER_FIELD_COLUMN_NAMES_SET = Set.new(NEW_NUMBER_FIELD_COLUMN_NAMES)

  def ff_def
    self[:flexifield_def_id]
  end

  def ff_def=(ff_def_id)
    self.flexifield_def_id = ff_def_id
  end

  def get_ff_value(ff_alias, field = nil)
    field ||= fields_from_cache[ff_alias]
    if field
      process_while_reading field
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end

  def set_ff_value(ff_alias, ff_value, field = nil)
    field ||= fields_from_cache[ff_alias]
    if field
      ff_value = nil if ff_value.blank?
      process_while_writing field, ff_value
    else
      raise ArgumentError, "Flexifield alias: #{ff_alias} not found in flexifeld def mapping"
    end
  end

  def assign_ff_values(args_hash)
    unless args_hash.is_a? Hash
      raise ArgumentError, 'Method argument must be a hash'
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
    ff_aliases.each_with_object({}) do |ff_alias, ff_values|
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

  def write_ff_attribute(attribute, value, field_type)
    if self.class.flexiblefield_names_set.include?(attribute.to_s) && ALLOWED_FIELD_TYPES.include?(field_type)
      self[attribute] = value
    else
      Rails.logger.info "Trying to write #{attribute} with value #{value}; Field doesnt exist"
    end
  end

  def read_ff_attribute(attribute, field_type)
    if self.class.flexiblefield_names_set.include?(attribute.to_s) && ALLOWED_FIELD_TYPES.include?(field_type)
      self[attribute]
    else
      Rails.logger.info "Trying to read #{attribute}; Field doesnt exist"
      nil
    end
  end

  def attribute_changes
    @attribute_changes ||= {}
  end

  class << self
    def flexiblefield_names
      @flexiblefield_names ||= column_names.grep(/ff.+/)
    end

    def flexiblefield_names_set
      @flexiblefield_names_set ||= Set.new(flexiblefield_names)
    end
  end

  def nested_field_correction
    NestedFieldCorrection.new(self, read_transformer).clear_child_levels
  end

  private
    def process_while_reading(field)
      field_type = field.field_type
      ff_value = Time.use_zone('UTC') { read_ff_attribute(field.column_name, field_type) }
      return (ff_value ? true : false) if field.field_type.to_s.to_sym == :custom_checkbox
      return nil if ff_value.blank?

      case field_type
      when 'custom_dropdown', 'nested_field'
        read_transformer.transform(ff_value, field.flexifield_name)
      else
        ff_value
      end
    end

    def process_while_writing(field, ff_value)
      old_value = read_transformer.transform(self[field.column_name], field.flexifield_name)
      attribute_changes[field.column_name.to_s] = [old_value, ff_value]
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

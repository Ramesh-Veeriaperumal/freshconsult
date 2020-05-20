class FlexifieldDef < ActiveRecord::Base
  include Helpdesk::Ticketfields::Constants
  include FlexifieldConstants

  self.primary_key = :id

  belongs_to_account
  belongs_to :survey

  attr_protected  :account_id

  has_many :flexifield_def_entries, class_name: 'FlexifieldDefEntry', order: 'flexifield_order', dependent: :destroy do
    def with_active_ticket_field
      joins(:active_ticket_field)
    end
  end
  accepts_nested_attributes_for :flexifield_def_entries,
    :reject_if => proc { |attrs| attrs['flexifield_alias'].blank? }

  has_many :flexifield_picklist_vals, :class_name => 'FlexifieldPicklistVal',:through =>:flexifield_def_entries

  scope :default_form, :conditions => ["product_id is NULL and module='Ticket'"]

  validates_presence_of :name

  # after_update :save_entries
  TEXT_GROUP = ['text', 'nested_field', 'dropdown', 'file'].freeze
  DN_TEXT_GROUP = ['text', 'file'].freeze

  TEXT_COL_TYPES  = ["text",    "paragraph"]
  NUM_COL_TYPES   = ["number",  "decimal"]

  CUSTOM_FF_ALIAS_TYPES = [:boolean, :integer]

  CUSTOM_FF_ALIAS_TYPES.each do |type|
    define_method "#{type}_ff_aliases" do
      flexifield_column_hash =  self.account.flexifields.columns_hash
      ff_alias_column_mapping.map { |key, value| key if flexifield_column_hash[value] && flexifield_column_hash[value].type == type }.compact
    end
  end

  def to_ff_field ff_alias
    ff_alias_column_mapping[ff_alias.to_s]
  end

  def to_ff_alias ff_field
    ff_column_alias_mapping[ff_field.to_s]
  end

  def to_ff_def_entry ff_alias
    (flexifield_def_entries || []).find { |f| f.flexifield_alias == ff_alias.to_s }
  end

  def ff_aliases
    @ff_aliases ||= flexifield_def_entries.nil? ? [] : flexifield_def_entries.with_active_ticket_field.map(&:flexifield_alias)
  end

  def ff_alias_column_mapping
    @ff_alias_column_mapping ||= flexifield_def_entries.with_active_ticket_field.each_with_object({}) { |ff_def_entry, hash| hash[ff_def_entry.flexifield_alias] = ff_def_entry.flexifield_name }
  end

  def ff_column_alias_mapping
    @ff_column_alias_mapping ||= flexifield_def_entries.with_active_ticket_field.each_with_object({}) { |ff_def_entry, hash| hash[ff_def_entry.flexifield_name] = ff_def_entry.flexifield_alias }
  end

  def ff_alias_column_type_mapping
    @ff_alias_column_type_mapping ||= flexifield_def_entries.with_active_ticket_field.each_with_object({}) do |ff_def_entry, hash|
      hash[ff_def_entry.flexifield_alias] = [ff_def_entry.flexifield_name, ff_def_entry.flexifield_coltype]
    end
  end

  def boolean_ff_aliases
    flexifield_column_hash =  self.account.flexifields.columns_hash
    ff_alias_column_mapping.map { |key, value| key if (flexifield_column_hash[value] && flexifield_column_hash[value].type) == :boolean }.compact
  end

  def non_text_ff_aliases
    flexifield_def_entries.nil? ? [] : non_text_fields.map(&:flexifield_alias)
  end

  def text_ff_aliases
    flexifield_def_entries.nil? ? [] : text_fields.map(&:flexifield_alias)
  end

  def ff_fields
    flexifield_def_entries.nil? ? [] : flexifield_def_entries.map(&:flexifield_name)
  end

  def non_text_ff_fields
    flexifield_def_entries.nil? ? [] : non_text_fields.map(&:flexifield_name)
  end

  def text_ff_fields
    flexifield_def_entries.nil? ? [] : text_fields.map(&:flexifield_name)
  end

  def text_and_number_ff_fields
    flexifield_def_entries.nil? ? [] : text_and_number_fields.map(&:flexifield_name)
  end

  def unassigned_flexifield_names # Dead code, returns wrong result
    Flexifield.flexiblefield_names - ff_fields
  end

  def first_available_column(type)
    used_hash = used_fields_hash(type)
    if text_group_include?(type) # change
      result = []
      used_hash.each { |key, value| result += value }
      check_limit_exceeded_for_text_or_dropdown(used_hash, type) ? fetch_available(result, type) : nil
    elsif type.to_s.to_sym == :checkbox
      check_checkbox_count(used_hash.count) ? fetch_available(used_hash, type) : nil
    elsif type.to_s.to_sym == :number
      check_number_field_count(used_hash.count) ? fetch_available(used_hash, type) : nil
    elsif type.to_s.to_sym == :date
      check_date_field_count(used_hash.count) ? fetch_available(used_hash, type) : nil
    else
      check_limit_exceeded_for_other_fields(used_hash, type) ? fetch_available(used_hash, type) : nil
    end
  end

  private

  def save_entries
    flexifield_def_entries.each do |entry|
      entry.save false
    end
  end

  def non_text_fields
    flexifield_def_entries.select {|field| !TEXT_COL_TYPES.include?(field.flexifield_coltype)}
  end

  def text_fields
    flexifield_def_entries.select {|field| TEXT_COL_TYPES.include?(field.flexifield_coltype)}
  end

  def text_and_number_fields
    flexifield_def_entries.select {|field| (TEXT_COL_TYPES + NUM_COL_TYPES).include?(field.flexifield_coltype)}
  end

  def used_fields_hash(type)
    @used_fields_hash ||= {}
    if text_group_include?(type)
      @used_fields_hash['text_and_dropdown'] ||= begin
        fields = used_fields(type)
        fetch_used_hash_for_text_or_dropdown(fields)
      end
    else
      @used_fields_hash[type] ||= begin
        fields = used_fields(type)
        fields.map(&:flexifield_name)
      end
    end
  end

  def used_fields(type)
    @used_fields ||= flexifield_def_entries.where(flexifield_coltype: field_mappings_required(type)).all
  end

  def field_mappings_required(type)
    if text_group_include?(type)
      if type == 'text'
        FIELD_COLUMN_MAPPING['dropdown'.to_sym][0] + ['file']
      else
        FIELD_COLUMN_MAPPING[type.to_sym][0]
      end
    else
      FIELD_COLUMN_MAPPING[type.to_sym][0]
    end
  end

  def fetch_used_hash_for_text_or_dropdown(fields)
    required_fields_hash = {}
    TEXT_AND_DROPDOWN_FIELD_DETAILS.each do |key, value|
      required_fields_hash[key] = select_fields(fields, *value)
    end
    required_fields_hash
  end

  def check_limit_exceeded_for_text_or_dropdown(hash, type)
    if dn_text_group_include?(type)
      text_hash = hash[:ffs_and_text_only] + hash[:denormalized_and_text]
      text_hash.count < TICKET_FIELD_DATA_DROPDOWN_COUNT
    else
      req_fields = hash[:ffs_and_dropdown_only]
      req_fields.count < (account.ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_DROPDOWN_COUNT : FFS_LIMIT)
    end
  end

  def check_checkbox_count(existing_count)
    existing_count < (account.ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_CHECKBOX_COUNT : CHECKBOX_FIELD_COUNT)
  end

  def check_date_field_count(existing_count)
    existing_count < (account.ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_DATE_FIELD_COUNT : DATE_FIELD_COUNT)
  end

  def check_number_field_count(existing_count)
    existing_count < (account.ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_NUMBER_COUNT : NUMBER_FIELD_COUNT)
  end

  def check_limit_exceeded_for_other_fields(fields, type)
    fields.length < DEFAULT_MAX_ALLOWED_FIELDS[type.to_sym]
  end

  def fetch_available(req_hash, type)
    value = account.ticket_field_limit_increase_enabled? ? (TICKET_FIELD_DATA_COLUMN_MAPPING[type.to_sym][1] - req_hash).first : (FIELD_COLUMN_MAPPING[type.to_sym][1] - req_hash).first
    add_to_used_hash(value, type)
    value
  end

  def add_to_used_hash(value, type)
    if text_group_include?(type)
      dn_text_group_include?(type) ? @used_fields_hash['text_and_dropdown'][:denormalized_and_text] << value : @used_fields_hash['text_and_dropdown'][:ffs_and_dropdown_only] << value
    else
      @used_fields_hash[type] << value
    end
  end

  def select_fields(fields, field_name, coltype)
    fields.select { |field| field.flexifield_name.include?(field_name) && field.flexifield_coltype == coltype }.map(&:flexifield_name)
  end

  def text_group_include?(type)
    TEXT_GROUP.include?(type)
  end

  def dn_text_group_include?(type)
    DN_TEXT_GROUP.include?(type)
  end
end

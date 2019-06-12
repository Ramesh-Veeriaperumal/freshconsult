class FlexifieldDef < ActiveRecord::Base
  include Helpdesk::Ticketfields::Constants
  include FlexifieldConstants

  self.primary_key = :id
  
  belongs_to_account
  belongs_to :survey
  
  attr_protected  :account_id

  has_many :flexifield_def_entries, :class_name => 'FlexifieldDefEntry', :order => 'flexifield_order', :dependent => :destroy
  accepts_nested_attributes_for :flexifield_def_entries,
    :reject_if => proc { |attrs| attrs['flexifield_alias'].blank? }
    
  has_many :flexifield_picklist_vals, :class_name => 'FlexifieldPicklistVal',:through =>:flexifield_def_entries

  scope :default_form, :conditions => ["product_id is NULL and module='Ticket'"]
  
  validates_presence_of :name
  
  # after_update :save_entries
  
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
    idx = nil
    ffa = "#{ff_alias}"
    ff_aliases.each_with_index do |c,i|
      idx = i if c == ffa
    end
    idx ? flexifield_def_entries[idx].to_ff_field : nil
  end

  def to_ff_alias ff_field
    idx = nil
    fff = "#{ff_field}" #make sure it is a string
    ff_fields.each_with_index do |c,i|
      idx = i if c == fff
    end
    idx ? flexifield_def_entries[idx].to_ff_alias : nil
  end

  def to_ff_def_entry ff_alias
    (flexifield_def_entries || []).find { |f| f.flexifield_alias == ff_alias.to_s }
  end
  
  def to_ff_def_entry ff_alias
    (flexifield_def_entries || []).find { |f| f.flexifield_alias == ff_alias.to_s }
  end

  def ff_aliases
    flexifield_def_entries.nil? ? [] : flexifield_def_entries.map(&:flexifield_alias)
  end

  def ff_alias_column_mapping
    @mapping ||= flexifield_def_entries.each_with_object({}) { |ff_def_entry, hash| hash[ff_def_entry.flexifield_alias] = ff_def_entry.flexifield_name }
  end

  def ff_alias_column_type_mapping
    @ff_alias_column_type_mapping ||= flexifield_def_entries.each_with_object({}) { |ff_def_entry, hash| hash[ff_def_entry.flexifield_alias] = [ff_def_entry.flexifield_name, ff_def_entry.flexifield_coltype] }
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
    if text_or_dropdown?(type) # change
      result = []
      used_hash.each { |key, value| result += value }
      check_limit_exceeded_for_text_or_dropdown(used_hash, type) ? fetch_available(result, type) : nil
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
    if text_or_dropdown?(type)
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
    if type.eql?('date') || type.eql?('date_time')
      [FIELD_COLUMN_MAPPING['date'.to_sym][0], FIELD_COLUMN_MAPPING['date_time'.to_sym][0]]
    elsif text_or_dropdown? type
      FIELD_COLUMN_MAPPING['dropdown'.to_sym][0]
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
    text_hash = hash[:ffs_and_text_only] + hash[:denormalized_and_text]
    if type == 'text'
      text_hash.count < TICKET_FIELD_DATA_DROPDOWN_COUNT
    else
      req_fields = hash[:ffs_and_dropdown_only]
      req_fields.count < (account.ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA_DROPDOWN_COUNT : FFS_LIMIT)
    end
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
    if text_or_dropdown?(type)
      type == 'text' ? @used_fields_hash['text_and_dropdown'][:denormalized_and_text] << value : @used_fields_hash['text_and_dropdown'][:ffs_and_dropdown_only] << value
    else
      @used_fields_hash[type] << value
    end
  end

  def select_fields(fields, field_name, coltype)
    fields.select { |field| field.flexifield_name.include?(field_name) && field.flexifield_coltype == coltype }.map(&:flexifield_name)
  end

  def text_or_dropdown?(type)
    type.eql?('text') || type.eql?('nested_field') || type.eql?('dropdown')
  end
end

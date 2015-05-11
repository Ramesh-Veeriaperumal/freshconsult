class FlexifieldDef < ActiveRecord::Base
  self.primary_key = :id
  
  belongs_to :account
  
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
  
  def ff_aliases
    flexifield_def_entries.nil? ? [] : flexifield_def_entries.map(&:flexifield_alias)
  end
  
  def non_text_ff_aliases
    flexifield_def_entries.nil? ? [] : non_text_fields.map(&:flexifield_alias)                                                   
  end

  def ff_fields
    flexifield_def_entries.nil? ? [] : flexifield_def_entries.map(&:flexifield_name)
  end
  
  def non_text_ff_fields
    flexifield_def_entries.nil? ? [] : non_text_fields.map(&:flexifield_name)
  end
  
  def unassigned_flexifield_names # Dead code, returns wrong result
    Flexifield.flexiblefield_names - ff_fields
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
end

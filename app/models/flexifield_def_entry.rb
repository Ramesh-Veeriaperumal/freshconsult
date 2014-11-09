# encoding: utf-8
class FlexifieldDefEntry < ActiveRecord::Base
  self.primary_key = :id

  include Cache::Memcache::FlexifieldDefEntry

  belongs_to_account
  belongs_to :flexifield_def

  has_many :flexifield_picklist_vals, :dependent => :destroy
  has_one :ticket_field, :class_name => 'Helpdesk::TicketField', :dependent => :destroy
  validates_presence_of :flexifield_name, :flexifield_alias, :flexifield_order

  scope :drop_down_fields, :conditions => {:flexifield_coltype => 'dropdown' }

  scope :event_fields, 
              :conditions => [ "flexifield_coltype = 'dropdown' or flexifield_coltype = 'checkbox'" ]  
  
  before_save :ensure_alias_is_one_word
  before_create :set_account_id

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.clear_cache }, on: :create
  after_commit ->(obj) { obj.clear_cache }, on: :destroy
  
  ViewColumn = Struct.new(:object,:content) do
    def viewname
      object.name.gsub(/flexifield_/,"").titleize
    end
    def field
      object.name.to_sym
    end
  end
  
  def self.view_columns
    columns.map{|c| ViewColumn.new(c) if [:integer,:string,:text].member?(c.type) && c.name =~ /flexifield_(?!.+_id)/}.compact
  end
  
  def self.wrap_form_columns(form_for)
    returning view_columns do |a|
      a.each do |c|
        case c.field
          when :flexifield_alias
            c.content= form_for.text_field(c.field)
          when :flexifield_name
            c.content= form_for.select(c.field, Flexifield.flexiblefield_names)
          when :flexifield_tooltip
            c.content= form_for.text_area(c.field, :cols => 80, :rows => 6)
          when :flexifield_order
            c.content= form_for.select(c.field, (1..32).to_a)
        end
      end
    end
  end
  
  def self.wrap_viewable_columns(css, lastcss)
    returning view_columns do |a|
      a[0..-2].each do |c|
        c.content= css
      end
      a.last.content= lastcss
    end
  end
  
  def self.ticket_db_column(alias_name)
    ff_entry = Account.current.flexifield_def_entries.find_by_flexifield_alias(alias_name)
    raise ActiveRecord::RecordNotFound unless ff_entry
    ff_entry.flexifield_name
  end

  def to_ff_field ff_alias = nil
    (ff_alias.nil? || flexifield_alias == ff_alias) ? flexifield_name : nil
  end
  def to_ff_alias ff_field = nil
    (ff_field.nil? || flexifield_name == ff_field) ? flexifield_alias : nil
  end

  def self.dropdown_custom_fields(account=Account.current)
    account.flexi_field_defs.first.flexifield_def_entries.
              drop_down_fields.all(:select => :flexifield_name).map(&:flexifield_name)
  end

  private

  def ensure_alias_is_one_word
    flexifield_alias.gsub!(/\s+/,"_")
  end
  
private
  def set_account_id
    self.account_id = flexifield_def.account_id
  end
 
  
end

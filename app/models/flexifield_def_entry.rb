# encoding: utf-8
class FlexifieldDefEntry < ActiveRecord::Base
  self.primary_key = :id

  include Cache::Memcache::FlexifieldDefEntry

  belongs_to_account
  belongs_to :flexifield_def

  has_many :flexifield_picklist_vals#, :dependent => :destroy # commenting to reduce a query while contact_field deletion
  has_one :ticket_field, :class_name => 'Helpdesk::TicketField'#, :dependent => :destroy # Confirm with Shan
  # This association is used in a Join condition in FlexifieldDaf. Since there is no foregin key mapping for `helpdesk_ticket_fields`
  # from `flexifield_def` filtering using account_id as well as deleted.
  has_one :active_ticket_field, class_name: 'Helpdesk::TicketField',
                                conditions: proc { 'helpdesk_ticket_fields.account_id = flexifield_def_entries.account_id AND helpdesk_ticket_fields.deleted = 0' }
  validates_presence_of :flexifield_name, :flexifield_alias, :flexifield_order

  scope :drop_down_fields, -> { where(flexifield_coltype: 'dropdown') }

  scope :event_fields, -> { joins(:active_ticket_field).where("flexifield_def_entries.flexifield_coltype = 'dropdown' or flexifield_def_entries.flexifield_coltype = 'checkbox'") }
  
  before_save :ensure_alias_is_one_word
  after_commit :clear_custom_date_field_cache, :clear_custom_date_time_field_cache, :clear_custom_file_field_name_cache
  before_create :set_account_id
  after_commit ->(obj) { obj.clear_flexifield_def_entry_cache }, on: :create  
  after_commit ->(obj) { obj.clear_flexifield_def_entry_cache }, on: :destroy

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  
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
    account.ticket_field_def.flexifield_def_entries.drop_down_fields.pluck(:flexifield_name)
  end

  private

  def ensure_alias_is_one_word
    flexifield_alias.gsub!(/\s+/,"_")
  end

  def clear_custom_date_field_cache
    Rails.logger.info "Clear date field cache for Account - #{account_id}, id - #{id}, colType - #{flexifield_coltype}"
    if self.flexifield_coltype == 'date'
      Rails.logger.info "Clearing date field cache for Account - #{account_id}"
      Account.current.clear_custom_date_fields_cache
    end
  end

  def clear_custom_date_time_field_cache
    Rails.logger.info "Clear date time field cache for Account - #{account_id}, id - #{id}, colType - #{flexifield_coltype}"
    if self.flexifield_coltype == Helpdesk::TicketField::DATE_TIME_FIELD
      Rails.logger.info "Clearing date time field cache for Account - #{account_id}"
      Account.current.clear_custom_date_time_fields_cache
    end
  end

  def clear_custom_file_field_name_cache
    Account.current.clear_custom_file_field_names_cache if flexifield_coltype == Helpdesk::TicketField::FILE_FIELD
  end

  def set_account_id
    self.account_id = flexifield_def.account_id
  end
 
 
end

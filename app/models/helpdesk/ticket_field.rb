class Helpdesk::TicketField < ActiveRecord::Base

  self.primary_key = :id
  serialize :field_options
  attr_writer :choices

  include Cache::FragmentCache::Base
  include Helpdesk::Ticketfields::TicketStatus
  include Cache::Memcache::Helpdesk::TicketField
  include DataVersioning::Model
  include Helpdesk::Ticketfields::PublisherMethods
  include Helpdesk::Ticketfields::Constants
  include Cache::Memcache::Admin::TicketField
  include Admin::TicketFieldConstants
  include Concerns::ActsAsListPositionUpdate

  clear_memcache [TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT, ACCOUNT_EVENT_FIELDS, ACCOUNT_FLEXIFIELDS]

  concerned_with :presenter

  self.table_name =  "helpdesk_ticket_fields"
  attr_accessible :name, :label, :label_in_portal, :description, :active, :field_type, :position,
                  :required, :visible_in_portal, :editable_in_portal, :required_in_portal,
                  :required_for_closure, :flexifield_def_entry_id, :field_options, :default, :deleted,
                  :level, :parent_id, :prefered_ff_col, :import_id, :choices, :picklist_values_attributes,
                  :ticket_statuses_attributes, :ticket_form_id, :column_name, :flexifield_coltype

  attr_accessor :skip_populate_choices, :error_on_limit_exceeded, :parent_level_choices

  CUSTOM_FIELD_PROPS = {
    custom_text: { type: :custom, dom_type: :text },
    custom_paragraph: { type: :custom, dom_type: :paragraph },
    custom_checkbox: { type: :custom, dom_type: :checkbox },
    custom_number: { type: :custom, dom_type: :number },
    custom_dropdown: { type: :custom, dom_type: :dropdown_blank },
    custom_date: { type: :custom, dom_type: :date },
    custom_date_time: { type: :custom, dom_type: :date },
    custom_decimal: { type: :custom, dom_type: :decimal },
    nested_field: { type: :custom, dom_type: :nested_field },
    encrypted_text: { type: :custom, dom_type: :encrypted_text },
    custom_file: { type: :custom, dom_type: :file },
    secure_text: { type: :custom, dom_type: :secure_text }
  }.freeze

  CUSTOM_DATE_TIME = 'custom_date_time'.freeze

  CUSTOM_FILE = 'custom_file'.freeze
  FILE_FIELD = 'file'.freeze
  SECURE_TEXT = 'secure_text'.freeze

  SKIP_FIELD_TYPES = [CUSTOM_DATE_TIME.to_sym, CUSTOM_FILE.to_sym].freeze

  DATE_TIME_FIELD = 'date_time'.freeze

  SECTION_LIMIT = 2
  FSM_SECTION_LIMIT = SECTION_LIMIT + 1
  NESTED_FIELD_LIMIT = 2

  SECTION_DROPDOWNS = ["default_ticket_type", "custom_dropdown"]
  NESTED_FIELD = 'nested_field'.freeze
  VERSION_MEMBER_KEY = 'TICKET_FIELD_LIST'.freeze
  concerned_with :presenter

  belongs_to_account
  belongs_to :flexifield_def_entry, :dependent => :destroy
  belongs_to :parent, :class_name => 'Helpdesk::TicketField'
  has_many :child_levels, :class_name => 'Helpdesk::TicketField',
                          :foreign_key => "parent_id",
                          :conditions => {:field_type => 'nested_field'},
                          :dependent => :destroy,
                          :order => "level", autosave: true

  has_many :custom_translations, :class_name => "CustomTranslation", :as => :translatable, :dependent => :destroy

  Language.all.each do |lang|
      has_one :"#{lang.to_key}_translation",
      :conditions => proc { { language_id: lang.id,
        account_id: Account.current.id } },
      :class_name => "CustomTranslation",
      :as => :translatable
  end

  has_many :list_all_choices, :class_name => 'Helpdesk::PicklistValue',
           foreign_key: :ticket_field_id, dependent: :destroy, autosave: true

  has_many :picklist_values, :as => :pickable,
                             :class_name => 'Helpdesk::PicklistValue',
                             :include => {:sub_picklist_values => :sub_picklist_values},
                             :dependent => :destroy,
                             order: 'position',
                             autosave: true

  has_many :level1_picklist_values, :as => :pickable,
                             :class_name => 'Helpdesk::PicklistValue',
                             :dependent => :destroy,
                             :order => "position"

  has_many :nested_ticket_fields, :class_name => 'Helpdesk::NestedTicketField',
                                  :dependent => :destroy,
                                  :order => "level",
                                  autosave: true

  has_many :nested_fields_with_flexifield_def_entries, :class_name => 'Helpdesk::NestedTicketField',
                                  :include => :flexifield_def_entry,
                                  :dependent => :destroy,
                                  :order => "level"

  has_many :ticket_statuses, :class_name => 'Helpdesk::TicketStatus', :order => "position"
  has_many :ticket_statuses_with_groups, class_name: 'Helpdesk::TicketStatus', dependent: :destroy,
                                         include: { status_groups: :group }, order: 'position', autosave: true

  has_many :sections, :class_name => 'Helpdesk::Section', :foreign_key => "ticket_field_id", :autosave => true, :dependent => :destroy
  has_many :section_fields, :dependent => :destroy, autosave: true
  has_many :dynamic_section_fields, :class_name => 'Helpdesk::SectionField',
                                    :foreign_key => :parent_ticket_field_id

  has_many :picklist_values_with_sections, :as => :pickable,
                             :class_name => 'Helpdesk::PicklistValue',
                             :include => {:section => {:section_fields => :ticket_field}},
                             :order => "position"

  has_many :custom_translations, class_name: 'CustomTranslation', as: :translatable, dependent: :destroy, inverse_of: :translatable

  Language.all.each do |lang|
    has_one :"#{lang.to_key}_translation",
    conditions: proc { { language_id: lang.id, account_id: Account.current.id } },
    class_name: 'CustomTranslation',
    as: :translatable
  end

  validates_associated :ticket_statuses, :if => :status_field?
  accepts_nested_attributes_for :ticket_statuses, :allow_destroy => true
  accepts_nested_attributes_for :picklist_values, :allow_destroy => true

  before_validation :populate_choices, :clear_ticket_type_cache

  before_destroy :update_ticket_filter, :save_deleted_field_info

  before_save :set_portal_edit
  before_save :sanitize_params, if: -> { Account.current.ticket_field_revamp_enabled? }

  before_update :set_internal_field_values

  after_initialize :initialize_default_values, if: -> { Account.current.ticket_field_revamp_enabled? }

  # xss_terminate
  acts_as_list :scope => 'account_id = #{account_id} AND parent_id is null'

  # need to override position update/below method to avoid updating position for nested level
  before_destroy :decrement_positions_on_lower_items, if: -> { parent_id.nil? }
  before_create  :add_to_list_bottom, if: -> { parent_id.nil? }

  after_commit :clear_cache
  after_commit :clear_new_ticket_field_cache
  after_commit :clear_fragment_caches
  after_commit :clear_all_section_ticket_fields_cache
  after_commit :cleanup_secure_field_data, if: -> { field_type == SECURE_TEXT }, on: :destroy

  after_commit :construct_model_changes

  publishable

  def initialize_default_values
    self.field_options = {} if field_options.blank? || !field_options.is_a?(Hash)
    self.field_options = self.field_options.with_indifferent_access
    self.field_type ||= ''
  end

  def sanitize_params
    self.label = RailsFullSanitizer.sanitize(label) if label_changed?
    self.label_in_portal = RailsFullSanitizer.sanitize(label_in_portal) if label_in_portal_changed?
  end

  def clear_all_section_ticket_fields_cache
    Account.current.sections.reload.find_each do |section|
      key = section_required_ticket_fields_key(section.id)
      Rails.logger.info "---- Delete key---- #{key}----"
      MemcacheKeys.delete_from_cache key
    end
  end

  def frontend_position
    return position if section_field?

    account_ticket_field_position_mapping_from_cache[:db_to_ui][id]
  end

  def frontend_to_db_position(ui_position)
    return 1 if ui_position.blank?

    account_ticket_field_position_mapping_from_cache[:ui_to_db][ui_position]
  end

  def condition_valid?
    Account.current.ticket_field_revamp_enabled?
  end

  def picklist_values_with_sublevels
    list_choices = picklist_values_from_cache
    return list_choices unless nested_field?

    picklist_id_to_choice_map = list_choices.group_by(&:pickable_id)
    list_choices.each do |choice|
      choice.sub_level_choices ||= []
      choice.sub_level_choices.push(*(picklist_id_to_choice_map[choice.id] || []))
    end
    picklist_id_to_choice_map[id] || []
  end

  def fetch_available_column(type)
    return nil unless new_record?

    type = type.to_s.to_sym
    field_constant = if Account.current.ticket_field_limit_increase_enabled?
                       REVAMPED_TICKET_FIELD_DATA_LIMITS[type]
                     else
                       REVAMPED_FLEXIFIELD_LIMITS[type]
                     end
    common_types, all_fields, max_allowed_count = field_constant
    used_fields = []
    common_types = *common_types
    common_types.each { |col_type| used_fields += (fetch_flexifield_columns[col_type] || []) }
    used_fields.compact!
    (all_fields - used_fields).sort.first
  end

  def choices_by_sub_level(ticket_field)
    list_choices = ticket_field.picklist_values_from_cache
    picklist_id_to_choice_map = list_choices.group_by { |choice| choice.pickable_id }
    list_choices.each do |choice|
      choice.sub_level_choices ||= []
      choice.sub_level_choices.push(*(picklist_id_to_choice_map[choice.id] || []))
    end
    picklist_id_to_choice_map[ticket_field.id] || []
  end

  def update_in_progress?
    field_options[:update_in_progress]
  end

  def separate_choices_by_level
    @separate_choices_by_level ||= begin
      level_choice_index = Admin::TicketFieldConstants::PICKLIST_COLUMN_MAPPING[:choices]
      custom_picklist_choice_mapping.each do |choices|
        @tf_level1_choices ||= []
        @tf_level1_choices << (choices[0, 6]) # getting only level1 choices
        (choices[level_choice_index] || []).each do |level2_choices|
          @tf_level2_choices ||= []
          @tf_level2_choices << (level2_choices[0, 6]) # getting only level2 choices data
          @tf_level3_choices ||= []
          @tf_level3_choices << (level2_choices[level_choice_index] || []) # getting level3 choices
        end
      end
    end
  end

  def tf_level1_choices
    separate_choices_by_level
    @tf_level1_choices || []
  end

  def tf_level2_choices
    separate_choices_by_level
    @tf_level2_choices || []
  end

  def tf_level3_choices
    separate_choices_by_level
    @tf_level3_choices || []
  end

  def self.custom_fields_to_show
    CUSTOM_FIELD_PROPS.except(*SKIP_FIELD_TYPES)
  end

  def update_ticket_filter
    return unless dropdown_field? || nested_field? || field_type == 'default_internal_group'

    # 1. when the custom dropdown is being deleted, delete conditions associated with the field in ticket filters
    # 2. when the shared_ownership feature is disabled, shared_ownership fields will be deleted.
    #     Change the conditions with internal/any type to primary. Ex: any_agent_id to responder_id
    conditions = case field_type
    when "default_internal_group"
      [
        {:condition_key => TicketConstants::INTERNAL_GROUP_ID,  :replace_key => "group_id"},
        {:condition_key => TicketConstants::ANY_GROUP_ID,       :replace_key => "group_id"},
        {:condition_key => TicketConstants::INTERNAL_AGENT_ID,  :replace_key => "responder_id"},
        {:condition_key => TicketConstants::ANY_AGENT_ID,       :replace_key => "responder_id"}
      ]
    else
      [{condition_key: "flexifields.#{self.column_name}"}]
    end
    # Update ticket filter condition as well as custom dashboard widgets configured with this field
    Helpdesk::TicketFields::UpdateTicketFilter.perform_async({ field_id: self.id, :conditions => conditions })
  end

  def dropdown_field?
    field_type.include?('dropdown')
  end

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  validates_associated :flexifield_def_entry
  validates_presence_of :flexifield_def_entry, :if => :custom_field?

  before_create :populate_label


  scope :custom_fields, :conditions => ["flexifield_def_entry_id is not null"]
  scope :custom_dropdown_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'custom_dropdown'"]
  scope :non_encrypted_ticket_fields, :conditions => ["field_type != 'encrypted_text' and field_type != 'secure_text'"]
  scope :non_encrypted_custom_fields, conditions: ["flexifield_def_entry_id is not null and field_type != 'encrypted_text' and field_type != 'secure_text'"]
  scope :customer_visible, :conditions => { :visible_in_portal => true }
  scope :customer_editable, :conditions => { :editable_in_portal => true }
  scope :agent_required_fields, :conditions => { :required => true }
  scope :agent_required_fields_for_closure, :conditions => { :required_for_closure => true }
  scope :type_field, :conditions => { :name => "ticket_type" }
  scope :status_field, :conditions => { :name => "status" }
  scope :default_company_field, :conditions => {:name => "company"}
  scope :requester_field, :conditions => {:name => "requester"}
  scope :nested_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'nested_field'"]
  scope :nested_and_dropdown_fields, :conditions=>["flexifield_def_entry_id is not null and (field_type = 'nested_field' or field_type='custom_dropdown')"]
  scope :event_fields, :conditions=>["flexifield_def_entry_id is not null and (field_type = 'nested_field' or field_type='custom_dropdown' or field_type='custom_checkbox')"]
  scope :default_fields, -> { where(:default => true ) }
  scope :custom_checkbox_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'custom_checkbox'"]
  scope :encrypted_custom_fields, conditions: ["flexifield_def_entry_id is not null and field_type = 'encrypted_text'"]
  scope :secure_fields, -> { where(field_type: SECURE_TEXT) }
  scope :non_secure_fields, -> { where("field_type != '#{SECURE_TEXT}'") }


  # Enumerator constant for mapping the CSS class name to the field type
  FIELD_CLASS = { default_subject: { type: :default, dom_type: 'text', form_field: 'subject', visible_in_view_form: false, i18n_label: 'subject' },
                  default_requester: { type: :default, dom_type: 'requester', form_field: 'email', visible_in_view_form: false, i18n_label: 'requester' },
                  default_ticket_type: { type: :default, dom_type: 'dropdown_blank', i18n_label: 'ticket_type' },
                  default_status: { type: :default, dom_type: 'dropdown', i18n_label: 'status' },
                  default_priority: { type: :default, dom_type: 'dropdown', i18n_label: 'priority' },
                  default_group: { type: :default, dom_type: 'dropdown_blank', form_field: 'group_id', i18n_label: 'group' },
                  default_agent: { type: :default, dom_type: 'dropdown_blank', form_field: 'responder_id', i18n_label: 'agent' },
                  default_internal_group: { type: :default, dom_type: 'dropdown_blank', form_field: 'internal_group_id', i18n_label: 'internal_group' },
                  default_internal_agent: { type: :default, dom_type: 'dropdown_blank', form_field: 'internal_agent_id', i18n_label: 'internal_agent' },
                  default_source: { type: :default, dom_type: 'hidden', i18n_label: 'source' },
                  default_description: { type: :default, dom_type: 'html_paragraph', form_field: 'description_html', visible_in_view_form: false, i18n_label: 'description' },
                  default_product: { type: :default, dom_type: 'dropdown_blank', form_field: 'product_id', i18n_label: 'product' },
                  default_company: { type: :default, dom_type: 'dropdown_blank', form_field: 'company_id', i18n_label: 'company' },
                  custom_text: { type: :custom,  dom_type: 'text' },
                  custom_paragraph: { type: :custom,  dom_type: 'paragraph' },
                  custom_checkbox: { type: :custom,  dom_type: 'checkbox' },
                  custom_number: { type: :custom,  dom_type: 'number' },
                  custom_date: { type: :custom,  dom_type: 'date' },
                  custom_decimal: { type: :custom,  dom_type: 'decimal' },
                  custom_dropdown: { type: :custom,  dom_type: 'dropdown_blank' },
                  nested_field: { type: :custom,  dom_type: 'nested_field' },
                  encrypted_text: { type: :custom,  dom_type: 'encrypted_text' },
                  custom_date_time: { type: :custom, dom_type: 'date' },
                  custom_file: { type: :custom, dom_type: 'file' },
                  secure_text: { type: :custom,  dom_type: 'secure_text' } }.freeze

  FSM_FIELD_CLASS = { contact: { i18n_label: 'cf_fsm_contact_name' },
                      customer_phone_number: { i18n_label: 'cf_fsm_phone_number' },
                      service_location: { i18n_label: 'cf_fsm_service_location' },
                      appointment_start_time: { i18n_label: 'cf_fsm_appointment_start_time' },
                      appointment_end_time: { i18n_label: 'cf_fsm_appointment_end_time' },
                      customer_s_signature: { i18n_label: 'cf_fsm_customer_signature' } }.freeze

  CUSTOM_FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.select { |field_name, prop| prop[:type] == :custom }.keys.map(&:to_s).freeze

  MODIFIABLE_CUSTOM_FIELD_TYPES = Helpdesk::TicketField::FIELD_CLASS.select { |field_name, prop| prop[:type] == :custom }.except(*SKIP_FIELD_TYPES).keys.map(&:to_s).freeze

  def field_sections
    return [] unless has_sections?
    account_sections_from_cache[id]
  end

  def section_ticket_fields
    return [] unless has_sections?
    account_section_fields_from_cache[:parent_ticket_field][id]
  end

  def section_mappings
    account_section_fields_from_cache[:ticket_field][id] || []
  end

  def dependent_fields
    account_nested_ticket_field_children[id] || []
  end

  def section_picklist_mappings
    return [] unless has_sections?
    account_section_picklist_mapping_from_cache[id]
  end

  def condition_based_field
    !(encrypted_field? && !current_account.hipaa_and_encrypted_fields_enabled?) &&
      !(!default? && !current_account.custom_ticket_fields_enabled?) &&
      !(company_field? && !current_account.multiple_user_companies_enabled?) &&
      !(product_field? && current_account.products_from_cache.empty?) && (parent_id.nil?) &&
      !(secure_field? && !current_account.pci_compliance_field_enabled?) && true
  end

  def sort_by_position_excluding_section_field(ticket_field)
    if field_options[:section] && ticket_field.field_options[:section]
      position.to_i - position.to_i
    elsif self.field_options[:section]
      1
    elsif ticket_field.field_options[:section]
      -1
    else
      position.to_i - ticket_field.position.to_i
    end
  end

  def company_field?
    field_type == 'default_company'
  end

  def dom_type
    FIELD_CLASS[field_type.to_sym][:dom_type]
  end

  def field_name
    FIELD_CLASS[field_type.to_sym][:form_field] || name
  end

  def i18n_label
    default_label = FIELD_CLASS[field_type.to_sym] && FIELD_CLASS[field_type.to_sym][:i18n_label] # adding condition here for skill from decorator
    default_label ? I18n.t("ticket_fields.fields.#{default_label}") : default_custom_field
  end

  def default_custom_field
    custom_label = label_in_portal.to_s.parameterize.underscore
    custom_field_label = FSM_FIELD_CLASS[custom_label.to_sym] && FSM_FIELD_CLASS[custom_label.to_sym][:i18n_label]
    custom_field_label ? I18n.t("ticket_fields.field_service_fields.#{custom_field_label}") : label
  end

  def visible_in_view_form?
    view = FIELD_CLASS[field_type.to_sym][:visible_in_view_form]
    ( view.nil? || view )
  end

  def is_default_field?
    (FIELD_CLASS[field_type.to_sym][:type] === :default)
  end

  # Check for meta programming requirement.
  def custom_dropdown_field?
    field_type == 'custom_dropdown'
  end

  def custom_checkbox_field?
    field_type == 'custom_checkbox'
  end

  def parent_field
    if level == 3
      parent.child_levels.find { |sub_level_field| sub_level_field.level == 2 }
    else
      parent
    end
  end

  def flexifield_name
    column_name || flexifield_def_entry.try(:flexifield_name)
  end

  def child_nested_field?
    nested_field? && level.present?
  end

  def parent_nested_field?
    nested_field? && level.nil?
  end

  def nested_field?
    field_type == 'nested_field'
  end

  def self.default_field_order
    Account.current.shared_ownership_enabled? ?
      TicketConstants::SHARED_DEFAULT_FIELDS_ORDER.keys : TicketConstants::DEFAULT_FIELDS_ORDER
  end

  # Used by API V2
  def formatted_nested_choices
    picklist_values.collect { |c|
      [c.value, c.sub_picklist_values.collect{ |c|
        [c.value, c.sub_picklist_values.collect{ |c|
          c.value
        }]
      }.to_h]
    }.to_h
  end

  def choices(ticket = nil, admin_pg = false)
    case field_type
      when "custom_dropdown" then
        if(admin_pg)
          picklist_values.collect { |c| [c.value, c.value, c.id] }
        else
          picklist_values.collect { |c| [c.value, c.value] }
        end
      when "default_priority" then
       TicketConstants.priority_names
      when "default_source" then
       TicketConstants.source_names
      when "default_status" then
       Helpdesk::TicketStatus.statuses_from_cache(Account.current)
      when "default_ticket_type" then
        if(admin_pg)
          Account.current.ticket_types_from_cache.collect { |c| [c.value, c.value, c.id] }
        else
          Account.current.ticket_types_from_cache.collect { |c| [c.value, c.value] }
        end
      when "default_agent" then
        return group_agents(ticket)
      when "default_group" then
        Account.current.groups_from_cache.collect { |c| [CGI.escapeHTML(c.name), c.id] }
      when "default_internal_agent" then
        return group_agents(ticket, true)
      when "default_internal_group" then
        return internal_group_choices(ticket)
      when "default_product" then
       Account.current.products.collect { |e| [CGI.escapeHTML(e.name), e.id] }
      when "nested_field" then
       picklist_values.collect { |c| [c.value, c.value] }
      else
        []
    end
  end

  def nested_choices
    self.picklist_values.collect { |c|
      [c.value, c.value, c.sub_picklist_values.collect { |sub_c|
            [sub_c.value, sub_c.value, sub_c.sub_picklist_values.collect { |i_c| [i_c.value,i_c.value] } ] }
      ]
    }
  end

  def nested_field_choices_by_id(picklist_values = self.picklist_values)
    picklist_values.collect do |c|
      {
        name: c.value,
        value: c.value,
        id: c.id,
        choices: nested_field_choices_by_id(c.sub_picklist_values)
      }
    end
  end

  def dropdown_choices_with_name
    level1_picklist_values.collect { |c| [c.value, c.value] }
  end

  def dropdown_choices_with_picklist_id
    level1_picklist_values.collect { |c| [c.picklist_id, c.picklist_id] }
  end

  def dropdown_choices_with_id
    level1_picklist_values.collect { |c| [c.id, c.value] }
  end

  def dropdown_choices_with_picklist_id
    level1_picklist_values.collect { |c| [c.picklist_id, c.picklist_id] }
  end

  def nested_choices_with_id
    self.picklist_values.collect { |c|
      [c.id, c.value, c.sub_picklist_values.collect { |sub_c|
            [sub_c.id, sub_c.value, sub_c.sub_picklist_values.collect { |i_c| [i_c.id,i_c.value] } ] }
      ]
    }
  end

  def nested_choices_with_special_case special_cases = []
    special_cases = special_cases.collect{ |default|
                                            Helpdesk::PicklistValue.new(:value =>default[0]) }

    (special_cases + self.picklist_values).collect{ |c|
        current_sp = []
        unless c.sub_picklist_values.empty? && special_cases.map(&:value).exclude?(c.value)
          current_sp = special_cases.select{ |sp| sp.value == c.value }
          current_sp = current_sp.empty? ? special_cases : current_sp
        end

        subcategory_val = (current_sp + c.sub_picklist_values).collect{ |sub_c|
          current_sp = []
          unless sub_c.sub_picklist_values.empty? && special_cases.map(&:value).exclude?(sub_c.value)
            current_sp = special_cases.select{ |sp| sp.value == sub_c.value }
            current_sp = current_sp.empty? ? special_cases : current_sp
          end

          item_val = (current_sp + sub_c.sub_picklist_values).collect{ |i_c|
            [i_c.value, i_c.value]
          };
        [sub_c.value, sub_c.value, item_val ]
        };
      [c.value, c.value, subcategory_val ]
    };
  end

  def html_unescaped_choices(ticket = nil, include_translation = false)
    case field_type
      when "custom_dropdown" then
        picklist_values.collect do |cd|
          translated_picklist_value = include_translation ? translated_choice(cd) : cd.value
          [CGI.unescapeHTML(translated_picklist_value), cd.value, {"data-id" => cd.id}]
        end
      when "default_priority" then
        TicketConstants.priority_names
      when "default_source" then
        TicketConstants.source_names
      when "default_status" then
        Helpdesk::TicketStatus.statuses_from_cache(Account.current).collect{|c|  [CGI.unescapeHTML(c[0]),c[1]] }
      when "default_ticket_type" then
        ticket_types = Account.current.ticket_types_from_cache.select{ |type| type.value != Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE }
        ticket_types.collect { |c| [CGI.unescapeHTML(include_translation ? translated_choice(c) : c.value), c.value,
                               {"data-id" => c.id}] }
      when "default_agent" then
        return group_agents(ticket)
      when "default_group" then
        Account.current.groups_from_cache.select { |group| group.group_type == GroupConstants::SUPPORT_GROUP_ID }.collect { |c| [c.name, c.id] }
      when "default_internal_agent" then
        return group_agents(ticket, true)
      when "default_internal_group" then
        internal_group_choices(ticket)
      when "default_product" then
        Account.current.products.collect { |e| [e.name, e.id] }
      when "default_company" then
         requester_companies(ticket)
      when "nested_field" then
        picklist_values.collect do |c|
          translated_picklist_value = include_translation ? translated_choice(c) : c.value
          [CGI.unescapeHTML(translated_picklist_value), c.value]
        end
      else
        []
     end
  end

  def requester_companies ticket
    if ticket && !ticket.new_record?
      companies = ticket.requester.companies.sorted.collect { |c| [c.name, c.id] }
      if ticket.company_id && !ticket.requester.company_ids.include?(ticket.company_id)
        old_company = account.companies.find_by_id(ticket.company_id)
        companies.push([old_company.name, old_company.id]) if old_company.present?
      end
    end
    companies.present? ? companies : []
  end

  def all_status_choices(disp_col_name=nil)
    disp_col_name = disp_col_name.nil? ? "customer_display_name" : "name"
    self.ticket_statuses.collect{|st| [Helpdesk::TicketStatus.translate_status_name(st, disp_col_name), st.status_id]}
  end

  def visible_status_choices(disp_col_name=nil)
    disp_col_name = disp_col_name.nil? ? "customer_display_name" : "name"
    self.ticket_statuses.visible.collect{|st| [Helpdesk::TicketStatus.translate_status_name(st, CGI.unescapeHTML(disp_col_name), translation_record), st.status_id]}
  end

  def nested_levels
    nested_ticket_fields.map{ |l| { :id => l.id, :label => l.label, :label_in_portal => l.translated_label_in_portal,
      :name => l.name, :level => l.level, :field_type => "nested_child" } } if field_type == "nested_field"
  end

  def levels
    nested_ticket_fields.map{ |l| { :id => l.id, :label => l.label, :label_in_portal => l.label_in_portal,
      :description => l.description, :level => l.level, :position => 1,
      :type => "dropdown" } } if field_type == "nested_field"
  end

  def level_three_present
    (nested_ticket_fields.last.level == 3) if field_type == "nested_field"
  end

  def dropdown_selected(dropdown_values, selected_value)
      selected_text = ""
      dropdown_values.each do |i|
        if (i[1] == selected_value)
           selected_text = i[0]
           break
        end
      end
      selected_text
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id], :root => 'helpdesk_ticket_field') do |xml|
      if field_type == "nested_field"
        xml.nested_ticket_fields do
          nested_ticket_fields.each do |nested_ticket_field|
            xml.nested_ticket_field do
              xml.tag!("id",nested_ticket_field.id)
              xml.tag!("name",nested_ticket_field.name)
              xml.tag!("label",nested_ticket_field.label)
              xml.tag!("label_in_portal",nested_ticket_field.label_in_portal)
              xml.tag!("level",nested_ticket_field.level)
            end
          end
        end
        xml.choices do
          picklist_values.each do |picklist_value|
            xml.option do
              xml.tag!("id",picklist_value.id)
              xml.tag!("value",picklist_value.value)
              to_xml_nested_fields(xml, picklist_value)
            end
          end
        end
      else
        xml.choices do
          choices.each do |k,v|
            if v != "0"
              xml.option do
                xml.tag!("id",k)
                xml.tag!("value",v)
              end
            end
          end
        end
      end
    end
  end


  #Use as_json instead of to_json for future support Rails3 refer:(http://jonathanjulian.com/2010/04/rails-to_json-or-as_json/)
  def as_json(options={})
    return super(options) unless options[:tailored_json].blank?
    options[:include] = [:nested_ticket_fields]
    options[:except] = [:account_id]
    options[:methods] = [:choices]
    options[:methods] = [:nested_choices] if field_type == "nested_field"
    super options
  end

  def to_xml_nested_fields(xml, picklist_value)
    return if picklist_value.sub_picklist_values.empty?

    xml.choices do
      picklist_value.sub_picklist_values.each do |sub_picklist_value|
        xml.option do
          xml.tag!("id",sub_picklist_value.id)
          xml.tag!("value",sub_picklist_value.value)
          to_xml_nested_fields(xml, sub_picklist_value)
        end
      end
    end
  end

  def company_cc_in_portal?
    field_options.fetch("portalcc") && field_options.fetch("portalcc_to").eql?("company")
  end

  def all_cc_in_portal?
    field_options.fetch("portalcc") && field_options.fetch("portalcc_to").eql?("all")
  end

  def portal_cc_field?
    field_options.fetch("portalcc")
  end

  def shared_ownership_field?
    self.field_type == "default_internal_group" or self.field_type == "default_internal_agent"
  end

  def section_field?
    field_options.blank? ? false : field_options.symbolize_keys.fetch(:section, false)
  end

  def rollback_section_in_field_options
    self.field_options["section"] = false
    self.save
  end

  def section_dropdown?
    SECTION_DROPDOWNS.include?(self.field_type)
  end

  def has_sections?
    field_options.blank? ? false : field_options.symbolize_keys.fetch(:section_present, false)
  end

  def requester_field?
    field_type == DEFAULT_REQUESTER
  end

  def product_field?
    field_type == DEFAULT_PRODUCT
  end

  def has_sections_feature?
    Account.current.features?(:dynamic_sections)
  end

  def has_section?
    return true if Account.current.dynamic_sections_enabled?
    # if field_type == "custom_dropdown"
    #   return false if section_field?
    #   !dynamic_section_fields.blank?
    # else
    #   return false
    # end
  end

  def construct_choice(choice_attributes)
    picklist_values.build(choice_attributes)
  end

  def picklist_values_by_id
    case level
    when nil
      picklist_values.each_with_object({}) do |pv, h|
        h[pv.picklist_id] = pv.value
      end
    when 2
      parent.level_2_choices_by_id
    when 3
      parent.level_3_choices_by_id
    end
  end

  def picklist_ids_by_value
    case level
    when nil
      picklist_values.each_with_object({}) do |pv, h|
        h[pv.value.downcase] = pv.picklist_id
      end
    when 2
      parent.level_2_choices_by_value
    when 3
      parent.level_3_choices_by_value
    end
  end

  def level_2_choices_by_id
    choice_hash = {}
    picklist_values.each do |pv|
      pv.sub_picklist_values.each do |l2pv|
        choice_hash[l2pv.picklist_id] = l2pv.value
      end
    end
    choice_hash
  end

  def level_3_choices_by_id
    choice_hash = {}
    picklist_values.each do |pv|
      pv.sub_picklist_values.each do |l2pv|
        l2pv.sub_picklist_values.each do |l3pv|
          choice_hash[l3pv.picklist_id] = l3pv.value
        end
      end
    end
    choice_hash
  end

  def level_2_choices_by_value
    choice_hash = {}
    picklist_values.each do |pv|
      pv.sub_picklist_values.each do |l2pv|
        l2value = l2pv.value.downcase
        choice_hash[l2value] ||= {}
        choice_hash[l2value][pv.value.downcase] = l2pv.picklist_id
      end
    end
    choice_hash
  end

  def level_3_choices_by_value
    choice_hash = {}
    picklist_values.each do |pv|
      pv.sub_picklist_values.each do |l2pv|
        l2pv.sub_picklist_values.each do |l3pv|
          l3value = l3pv.value.downcase
          l2value = l2pv.value.downcase
          choice_hash[l3value] ||= {}
          choice_hash[l3value][l2value] ||= {}
          choice_hash[l3value][l2value][pv.value.downcase] = l3pv.picklist_id
        end
      end
    end
    choice_hash
  end

  def translated_label_in_portal(record = self)
    label = record.level.to_i > 1 ? "customer_label_#{record.level}" : 'customer_label'
    translation_record.present? && translation_record.translations[label].present? ? translation_record.translations[label] : record.label_in_portal
  end

  def translated_choice(picklist_value)
    translation_record.present? && translation_record.translations['choices'].present? ? translation_record.translations['choices']["choice_#{picklist_value.picklist_id}"] || picklist_value.value : picklist_value.value
  end

  def translated_nested_choices
    self.picklist_values.collect { |c|
      #Level value is being sent as a parameter for ease of translation
      [c.value, translated_choice(c), c.sub_picklist_values.collect { |sub_c|
            [sub_c.value, translated_choice(sub_c), sub_c.sub_picklist_values.collect { |i_c| [i_c.value,translated_choice(i_c)] } ] }
      ]
    }
  end

  def encrypted_field?
    field_type.to_sym == CUSTOM_FIELD_PROPS[:encrypted_text][:dom_type]
  end

  def secure_field?
    field_type.to_sym == CUSTOM_FIELD_PROPS[:secure_text][:dom_type]
  end

  def exclude_encrypted_field?
    encrypted_field? && !Account.current.falcon_and_encrypted_fields_enabled?
  end

  def fsm_reserved_custom_field?
    name.starts_with?(Admin::AdvancedTicketing::FieldServiceManagement::Constant::FSM_FIELDS_PREFIX)
  end

  def custom_date_time_field?
    self.field_type == CUSTOM_DATE_TIME
  end

  def self.field_name(label, account_id, exist = false, encrypted = false)
    label = label.gsub(/[^ _0-9a-zA-Z]+/, '')
    label = "#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}".squeeze('_')
    label = if label.blank?
      "rand#{rand(999_999)}"
    elsif exist
      "#{label}#{rand(999_999)}"
    else
      label
    end
    prefix = encrypted ? ENCRYPTED_FIELD_LABEL_PREFIX : CUSTOM_FIELD_LABEL_PREFIX
    "#{prefix}#{label}_#{account_id}"
  end

  def self.construct_label(label, encrypted = false)
    label = label.gsub(/[^ _0-9a-zA-Z]+/, '')
    label = label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase.squeeze('_')
    prefix = encrypted ? ENCRYPTED_LABEL_PREFIX_WITHOUT_CF : ''
    "#{prefix}#{label}"
  end

  def new_formatted_choices
    drop_or_nested = proc { |type| ['custom_dropdown', 'nested_field', 'default_ticket_type'].include?(type) }
    case field_type
      when drop_or_nested
        construct_dropdown_and_nested_choices(custom_picklist_choice_mapping, id)
      when 'default_priority'
        TicketConstants.priority_names.collect do |priority|
          { label: priority[0], value: priority[1] }
        end
      when 'default_source'
        if Account.current.ticket_source_revamp_enabled?
          Account.current.ticket_source_from_cache.map(&:new_response_hash)
        else
          TicketConstants.source_names.collect do |source|
            { label: source[0], value: source[1] }
          end
        end
      when 'default_status'
        ticket_field_statuses_from_cache.reject(&:deleted).sort_by(&:position).map(&:new_response_hash)
      else
        []
    end
  end

  def choices?
    default_choices_fields = %w(default_priority default_source default_status default_ticket_type custom_dropdown nested_field)
    default_choices_fields.include?(field_type)
  end

  def fsm?
    field_options['fsm']
  end

  def translation_record
    @translation_record ||= Account.current.custom_translations_enabled? && Account.current.supported_languages.include?(language.code) ? safe_send("#{language.to_key}_translation") : nil
  end

  protected

    def group_agents(ticket, internal_group = false)
      if ticket
        group_id = (internal_group ? ticket.internal_group_id : ticket.group_id)
        responder_id = (internal_group ? ticket.internal_agent_id : ticket.responder_id)
        if group_id.present?
          agent_list = AgentGroup.where({ :group_id => group_id, :users => {:account_id => Account.current.id , :deleted => false } }).joins(:user).select("users.id,users.name").order("users.name").collect{ |c| [c.name, c.id]}
          if !responder_id || agent_list.any? { |a| a[1] == responder_id }
            return agent_list
          end

          responder = Account.current.agents.find_by_user_id(responder_id)
          agent_list += [[ responder.user.name, responder_id ]] if responder
          return agent_list
        end
      end
      internal_group ? [] : Account.current.agents_details_from_cache.collect { |c| [c.name, c.id] }
    end

    def internal_group_choices ticket
      group_choices = []
      if ticket
        status_group_ids = ticket.ticket_status.present? ? ticket.ticket_status.group_ids : []
        group_choices = Account.current.groups_from_cache.collect {|c| [CGI.escapeHTML(c.name), c.id] if status_group_ids.include?(c.id)}.compact
      end
      group_choices
    end

    def populate_choices
      return if !@choices || skip_populate_choices

      if(["nested_field"].include?(self.field_type))
        clear_picklist_cache
        Account.current.nested_field_revamp_enabled? ? run_through_picklists_with_id(@choices, picklist_values, self)
          : run_through_picklists(@choices, picklist_values, self)
      elsif("default_status".eql?(self.field_type))
        @choices.each_with_index{|attr,position| update_ticket_status(attr,position)}
      end
    end

    def run_through_picklists_with_id(choices, picklists, parent)
      choices.each_with_index do |choice, index|
        choice.symbolize_keys!
        pl_id = choice[:id]
        pl_value = choice[:value]
        current_tree = picklists.find{ |p| p.id == pl_id}
        if current_tree
          current_tree.destroy and next if choice[:destroyed]
          current_tree.position = index + 1
          current_tree.value = pl_value
          if choice[:choices].present?
            run_through_picklists_with_id(choice[:choices],
                                  current_tree.sub_picklist_values,
                                  current_tree)
          end
        else
          build_picklists_with_id(choice, parent, index)
        end
      end
    end

    def build_picklists_with_id(choice, parent_pl_value, position=0)
      choice.except!(:id, :destroyed).merge(position: position+1)
      if parent_pl_value.id == self.id
        picklist_values.build(choice)
      else
        parent_pl_value.sub_picklist_values.build(choice)
      end
    end

    def run_through_picklists(choices, picklists, parent)
      choices.each_with_index do |choice, index|
        pl_value = choice[0]
        current_tree = picklists.find{ |p| p.value == pl_value}
        if current_tree
          current_tree.position = index + 1
          if choice[2]
            run_through_picklists(choice[2],
                                  current_tree.sub_picklist_values,
                                  current_tree)
          elsif current_tree.sub_picklist_values.present?
            current_tree.sub_picklist_values.destroy_all
          end
        else
          build_picklists(choice, parent, index)
        end
        clear_picklists(picklists.map(&:value) - choices.map { |c| c[0] }, picklists)
      end
    end

    def build_picklists(choice, parent_pl_value, position=nil)
      attributes = { :value => choice[0], :position => position+1 }
      attributes.merge!(:choices => choice[2]) if choice[2]
      if parent_pl_value.id == self.id
        picklist_values.build(attributes)
      elsif choice.size > 2 && choice[2].is_a?(Array)
        parent_pl_value.sub_picklist_values.build(attributes)
      else
        parent_pl_value.sub_picklist_values.build(attributes.except(:choices))
      end
    end

    def clear_picklists(values, pl_values)
      values.each do |value|
        pl_value = pl_values.find{ |p| p.value == value}
        pl_value.destroy if pl_value
      end
    end

    def clear_ticket_type_cache
      if(self.field_type.eql?("default_ticket_type"))
        clear_picklist_cache
      end
    end

    def populate_label
      self.label = name.titleize if label.blank?
      self.label_in_portal = label if label_in_portal.blank?
    end

    def set_portal_edit
      self.editable_in_portal = false unless visible_in_portal
      self
    end

    def set_internal_field_values
      if (self.name == "internal_agent" or self.name == "internal_group") and Account.current.shared_ownership_enabled?
        self.visible_in_portal = false
        self.editable_in_portal = false
        self.required_in_portal = false
        self.required_for_closure = false
        self.default = true
      end
    end

    def save_form_field_mapping
      save_form_field(self)
    end

    def remove_form_field_mapping
      remove_form_field(self)
    end

  private

    def construct_dropdown_and_nested_choices(choices, parent_id)
      result = []
      choices.each do |each_choice|
        data = {}
        PICKLIST_COLUMN_MAPPING.each_pair do |key, value|
          data[key] = if key == :choices
                        construct_dropdown_and_nested_choices(each_choice[value], each_choice[5])
                      elsif key == :parent_choice_id
                        parent_id
                      else
                        each_choice[value]
                      end
        end
        result << data
      end
      result
    end

    def status_field?
      self.field_type.eql?("default_status")
    end

    def source_field?
      self.field_type.eql?('default_source')
    end

    def type_field?
      self.field_type.eql?("default_ticket_type")
    end

    def custom_field?
      !self.default
    end

    def language
      Language.find_by_code(I18n.locale)
    end

    def cleanup_secure_field_data
      Tickets::VaultDataCleanupWorker.perform_async(field_names: [TicketDecorator.display_name(name)])
    end
end

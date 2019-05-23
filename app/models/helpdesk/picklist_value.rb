class Helpdesk::PicklistValue < ActiveRecord::Base
  
  include Redis::DisplayIdRedis
  include Redis::RedisKeys

  clear_memcache [ACCOUNT_SECTION_FIELD_PARENT_FIELD_MAPPING, ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING, TICKET_FIELDS_FULL, ACCOUNT_CUSTOM_DROPDOWN_FIELDS, ACCOUNT_TICKET_TYPES]

  belongs_to_account
  self.table_name =  "helpdesk_picklist_values"
  validates_presence_of :value
  validates_uniqueness_of :value, :scope => [:pickable_id, :pickable_type, :account_id], :if => 'pickable_id.present?'

  attr_accessor :required_ticket_fields, :section_ticket_fields
  
  belongs_to :pickable, :polymorphic => true

  has_many :sub_picklist_values, :as => :pickable, 
                                 :class_name => 'Helpdesk::PicklistValue', 
                                 :dependent => :destroy,
                                 :order => "position"

  has_one :section_picklist_mapping, :class_name => 'Helpdesk::SectionPicklistValueMapping', 
                                     :dependent => :destroy
  has_one :section, :class_name => 'Helpdesk::Section', :through => :section_picklist_mapping

  attr_accessible :value, :choices, :position

  accepts_nested_attributes_for :sub_picklist_values, :allow_destroy => true
  
  before_validation :trim_spaces, :if => :value_changed?

  before_create :assign_picklist_id, if: :redis_picklist_id_enabled?

  before_save :construct_model_changes

  before_destroy :save_deleted_picklist_info

  after_commit :clear_ticket_types_cache

  concerned_with :presenter

  publishable


  CACHEABLE_ATTRIBUTES = ["id", "account_id", "pickable_id", "pickable_type", "value", "position", "created_at", "updated_at"]
  
  # scope_condition for acts_as_list and as well for using index in fetching sub_picklist_values
  def scope_condition
    "pickable_id = #{pickable_id} AND #{connection.quote_column_name("pickable_type")} = 
    '#{pickable_type}'"
  end

  def custom_cache_attributes
    {
      :section_ticket_fields => section_ticket_fields
    }
  end

  def choices=(c_attr)
    sub_picklist_values.clear
    c_attr.each_with_index do |choice, index|
      sub_picklist_values.build(build_choice_attributes(choice, index))
    end 
  end

  def build_choice_attributes choice, index
    if Account.current.nested_field_revamp_enabled?
      choice.symbolize_keys!
      choice.except!(:id, :destroyed).merge!(position: index+1)
    else 
      attributes = {
        value: choice[0], 
        position: index+1
      }
      choice[2].present? ? attributes.merge!(choices: choice[2]) : attributes
    end
  end

  def required_ticket_fields
    @required_ticket_fields ||= filter_fields section_ticket_fields
  end

  def section_ticket_fields
    @section_ticket_fields ||= (section.present?) ? section.section_fields.map(&:ticket_field) : []
  end

  def choices
    sub_picklist_values.collect { |c| [c.value, c.value]}
  end 

  def self.with_exclusive_scope(method_scoping = {}, &block) # for account_id in sub_picklist_values query
    with_scope(method_scoping, :overwrite, &block)
  end

  def construct_model_changes
    @model_changes = self.changes.clone.to_hash
  end

  def save_deleted_picklist_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end
  
  def clear_ticket_types_cache
    ticket_type_id = Account.current.ticket_fields_from_cache.find { |x| x.name == 'ticket_type' }.id
    Account.current.clear_ticket_types_from_cache if pickable_id == ticket_type_id
  end

  private

    def assign_picklist_id
      key = PICKLIST_ID % { account_id: account_id }
      begin
        computed_id = $redis_display_id.evalsha(Redis::DisplayIdLua.picklist_id_lua_script, [:keys], key.to_a)
      rescue Redis::BaseError => e
        NewRelic::Agent.notice_error(e, {description: 'Redis Error', uuid: Thread.current[:message_uuid]})
        Rails.logger.debug "Redis Error, #{e.message}"
        if e.message.include?('NOSCRIPT No matching script')
          exception = true
          Redis::DisplayIdLua.load_picklist_id_lua_script
        end
      end
      if computed_id.nil?
        # this may not return accurate value until soft delete is implemented
        computed_id = account.picklist_values.maximum('picklist_id').to_i + 1
        set_display_id_redis_key(key, computed_id)
      end
      self.picklist_id = computed_id.to_i
    end

    def redis_picklist_id_enabled?
      account.redis_picklist_id_enabled?
    end

    def filter_fields fields
      fields.select {|field| field.required_for_closure? }
    end

    def trim_spaces
      value.to_s.strip!
    end

end

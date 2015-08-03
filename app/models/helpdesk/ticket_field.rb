class Helpdesk::TicketField < ActiveRecord::Base
  
  self.primary_key = :id
  serialize :field_options
  attr_writer :choices

  include Helpdesk::Ticketfields::TicketStatus
  include Cache::Memcache::Helpdesk::TicketField
  # add for multiform phase 1 migration
  include Helpdesk::Ticketfields::TicketFormFields
  
  self.table_name =  "helpdesk_ticket_fields"
  attr_accessible :name, :label, :label_in_portal, :description, :active, 
    :field_type, :position, :required, :visible_in_portal, :editable_in_portal, :required_in_portal, 
    :required_for_closure, :flexifield_def_entry_id, :field_options, :default, 
    :level, :parent_id, :prefered_ff_col, :import_id, :choices, :picklist_values_attributes, 
    :ticket_statuses_attributes

  CUSTOM_FIELD_PROPS = {  
    :custom_text            => { :type => :custom, :dom_type => :text},
    :custom_paragraph       => { :type => :custom, :dom_type => :paragraph},
    :custom_checkbox        => { :type => :custom, :dom_type => :checkbox},
    :custom_number          => { :type => :custom, :dom_type => :number},
    :custom_dropdown        => { :type => :custom, :dom_type => :dropdown_blank},
    # :custom_date            => { :type => :custom, :dom_type => :date},
    :custom_decimal         => { :type => :custom, :dom_type => :decimal},
    :nested_field           => { :type => :custom, :dom_type => :nested_field}
  }
  
  belongs_to :account
  belongs_to :flexifield_def_entry, :dependent => :destroy
  has_many :picklist_values, :as => :pickable, 
                             :class_name => 'Helpdesk::PicklistValue',
                             :include => :sub_picklist_values,
                             :dependent => :destroy, 
                             :order => "position"
  has_many :nested_ticket_fields, :class_name => 'Helpdesk::NestedTicketField', 
                                  :dependent => :destroy, 
                                  :order => "level"
    
  has_many :ticket_statuses, :class_name => 'Helpdesk::TicketStatus', :order => "position"

  has_many :section_fields, :dependent => :destroy
  has_many :dynamic_section_fields, :class_name => 'Helpdesk::SectionField', 
                                    :foreign_key => :parent_ticket_field_id


  validates_associated :ticket_statuses, :if => :status_field?
  accepts_nested_attributes_for :ticket_statuses, :allow_destroy => true
  accepts_nested_attributes_for :picklist_values, :allow_destroy => true

  before_validation :populate_choices, :clear_ticket_type_cache

  before_destroy :delete_from_ticket_filter
  # before_update :delete_from_ticket_filter
  before_save :set_portal_edit

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  # Phase1:- multiform , will be removed once migration is done.
  after_commit ->(obj) { obj.save_form_field_mapping }, on: :create
  after_commit ->(obj) { obj.save_form_field_mapping }, on: :update
  after_commit :remove_form_field_mapping, on: :destroy
  #Phase1:- end

  # xss_terminate
  acts_as_list :scope => 'account_id = #{account_id}'

  after_commit :clear_cache
  
  def delete_from_ticket_filter
    if is_dropdown_field?
      Account.current.ticket_filters.each do |filter|
        con_arr = filter.data[:data_hash]
        unless  con_arr.blank?
          con_arr.each do |condition|
            con_arr.delete(condition) if condition["condition"].eql?("flexifields.#{flexifield_def_entry.flexifield_name}")
          end
          filter.query_hash = con_arr
          filter.save
        end
      end
    end
  end
  
  def is_dropdown_field?
    field_type.include?("dropdown")
  end
   
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
  before_create :populate_label
  
  
  scope :custom_fields, :conditions => ["flexifield_def_entry_id is not null"]
  scope :custom_dropdown_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'custom_dropdown'"]
  scope :customer_visible, :conditions => { :visible_in_portal => true }
  scope :customer_editable, :conditions => { :editable_in_portal => true }
  scope :type_field, :conditions => { :name => "ticket_type" }
  scope :status_field, :conditions => { :name => "status" }
  scope :nested_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'nested_field'"]
  scope :nested_and_dropdown_fields, :conditions=>["flexifield_def_entry_id is not null and (field_type = 'nested_field' or field_type='custom_dropdown')"]
  scope :event_fields, :conditions=>["flexifield_def_entry_id is not null and (field_type = 'nested_field' or field_type='custom_dropdown' or field_type='custom_checkbox')"]


  # Enumerator constant for mapping the CSS class name to the field type
  FIELD_CLASS = { :default_subject              => { :type => :default, :dom_type => "text",
                                              :form_field => "subject", :visible_in_view_form => false },
                  :default_requester            => { :type => :default, :dom_type => "requester",
                                              :form_field => "email"  , :visible_in_view_form => false },
                  :default_ticket_type          => { :type => :default, :dom_type => "dropdown_blank"},
                  :default_status               => { :type => :default, :dom_type => "dropdown_blank"}, 
                  :default_priority             => { :type => :default, :dom_type => "dropdown"},
                  :default_group                => { :type => :default, :dom_type => "dropdown_blank", :form_field => "group_id"},
                  :default_agent                => { :type => :default, :dom_type => "dropdown_blank", :form_field => "responder_id"},
                  :default_source               => { :type => :default, :dom_type => "hidden"},
                  :default_description          => { :type => :default, :dom_type => "html_paragraph", 
                                              :form_field => "description_html", :visible_in_view_form => false },
                  :default_product              => { :type => :default, :dom_type => "dropdown_blank",
                                             :form_field => "product_id" },
                  :custom_text                  => { :type => :custom, :dom_type => "text"},
                  :custom_paragraph             => { :type => :custom, :dom_type => "paragraph"},
                  :custom_checkbox              => { :type => :custom, :dom_type => "checkbox"},
                  :custom_number                => { :type => :custom, :dom_type => "number"},
                  :custom_date                  => { :type => :custom, :dom_type => "date"},
                  :custom_decimal               => { :type => :custom, :dom_type => "decimal"},
                  :custom_dropdown              => { :type => :custom, :dom_type => "dropdown_blank"},
                  :nested_field                 => { :type => :custom, :dom_type => "nested_field"}
                }

  def dom_type
    FIELD_CLASS[field_type.to_sym][:dom_type]
  end

  def field_name
    FIELD_CLASS[field_type.to_sym][:form_field] || name
  end
  
  def visible_in_view_form?
    view = FIELD_CLASS[field_type.to_sym][:visible_in_view_form]
    ( view.nil? || view )
  end
  
  def is_default_field?
    (FIELD_CLASS[field_type.to_sym][:type] === :default)
  end

  def nested_field?
    field_type == "nested_field"
  end

  def api_choices(current_account)
    case field_type
    when "custom_dropdown"
      picklist_values.collect { |c| c.value }
    when "default_priority"
      Hash[TicketConstants.priority_names]
    when "default_source"
      Hash[TicketConstants.source_names]
    when "default_status"
      api_statuses = Helpdesk::TicketStatus.status_objects_from_cache(current_account).map{|status| 
                  [ 
                    status.status_id, [Helpdesk::TicketStatus.translate_status_name(status, 'name'), 
                    Helpdesk::TicketStatus.translate_status_name(status, 'customer_display_name') ]
                  ]
                }
      Hash[api_statuses]
    when "default_ticket_type"
      current_account.ticket_types_from_cache.collect { |c| c.value }
    when "default_agent"
      return Hash[current_account.agents_from_cache.collect { |c| [c.user.name, c.user.id] }]
    when "default_group"
      Hash[current_account.groups_from_cache.collect { |c| [CGI.escapeHTML(c.name), c.id] }]
    when "default_product"
      Hash[current_account.products_from_cache.collect { |e| [CGI.escapeHTML(e.name), e.id] }]
    when "nested_field"
      picklist_values.collect { |c| c.value }
    else
      []
    end
  end  

  def api_nested_choices
    picklist_values.collect { |c| 
      Hash[c.value, c.sub_picklist_values.collect{ |c| 
        Hash[c.value, c.sub_picklist_values.collect{ |c| 
          c.value
        }]
      }]
    }
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
         Helpdesk::TicketStatus.statuses_from_cache(account)
       when "default_ticket_type" then
          if(admin_pg)
            account.ticket_types_from_cache.collect { |c| [c.value, c.value, c.id] }
          else
            account.ticket_types_from_cache.collect { |c| [c.value, c.value] }
          end
       when "default_agent" then
        return group_agents(ticket)
       when "default_group" then
         account.groups_from_cache.collect { |c| [CGI.escapeHTML(c.name), c.id] }
       when "default_product" then
         account.products.collect { |e| [CGI.escapeHTML(e.name), e.id] }
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
  
  def dropdown_choices_with_id
    picklist_values.collect { |c| [c.id, c.value] }
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

  def html_unescaped_choices(ticket = nil)
    case field_type
       when "custom_dropdown" then
         picklist_values.collect { |c| [CGI.unescapeHTML(c.value), c.value] }
       when "default_priority" then
         TicketConstants.priority_names
       when "default_source" then
         TicketConstants.source_names
       when "default_status" then
         Helpdesk::TicketStatus.statuses_from_cache(account).collect{|c|  [CGI.unescapeHTML(c[0]),c[1]] }
       when "default_ticket_type" then
         account.ticket_types_from_cache.collect { |c| [CGI.unescapeHTML(c.value), 
                                                        c.value, 
                                                        {"data-id" => c.id}] }
       when "default_agent" then
        return group_agents(ticket)
       when "default_group" then
         account.groups_from_cache.collect { |c| [c.name, c.id] }
       when "default_product" then
         account.products.collect { |e| [e.name, e.id] }
       when "nested_field" then
         picklist_values.collect { |c| [CGI.unescapeHTML(c.value), c.value] }
       else
         []
     end
  end

  def all_status_choices(disp_col_name=nil)
    disp_col_name = disp_col_name.nil? ? "customer_display_name" : "name"
    self.ticket_statuses.collect{|st| [Helpdesk::TicketStatus.translate_status_name(st, disp_col_name), st.status_id]}
  end

  def visible_status_choices(disp_col_name=nil)
    disp_col_name = disp_col_name.nil? ? "customer_display_name" : "name"
    self.ticket_statuses.visible.collect{|st| [Helpdesk::TicketStatus.translate_status_name(st, CGI.unescapeHTML(disp_col_name)), st.status_id]}
  end

  def nested_levels
    nested_ticket_fields.map{ |l| { :id => l.id, :label => l.label, :label_in_portal => l.label_in_portal, 
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

  def section_field?
    field_options.blank? ? false : field_options.symbolize_keys.fetch(:section, false)
  end

  def has_sections_feature?
    account.features_included?(:dynamic_sections)
  end

  def has_section?
    return true if has_sections_feature? && field_type == "default_ticket_type"
    # if field_type == "custom_dropdown"
    #   return false if section_field?
    #   !dynamic_section_fields.blank?
    # else
    #   return false
    # end
  end
  
  protected

    def group_agents(ticket)
      if ticket && ticket.group_id
        agent_list = account.agent_groups.find(:all, 
                                               :joins =>"inner join users on 
                                                          agent_groups.account_id = 
                                                                    users.account_id and 
                                                          users.id = agent_groups.user_id",
                                               :conditions => { :group_id => ticket.group_id, 
                                                                :users => {:deleted => false}
                                                              }
                                              ).collect{ |c| [c.user.name, c.user.id]}

        if !ticket.responder_id || agent_list.any? { |a| a[1] == ticket.responder_id }
          return agent_list
        end

        responder = account.agents_from_cache.detect { |a| a.user.id == ticket.responder_id }
        agent_list += [[ responder.user.name, ticket.responder_id ]] if responder
        return agent_list
      end
      
      account.agents_from_cache.collect { |c| [c.user.name, c.user.id] }
    end

    def populate_choices
      return unless @choices
      if(["nested_field"].include?(self.field_type))
        clear_picklist_cache
        run_through_picklists(@choices, picklist_values, self)
      elsif("default_status".eql?(self.field_type))
        @choices.each_with_index{|attr,position| update_ticket_status(attr,position)}
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

    def save_form_field_mapping
      save_form_field(self)
    end

    def remove_form_field_mapping
      remove_form_field(self)
    end

  private
    def status_field?
      self.field_type.eql?("default_status")
    end
end

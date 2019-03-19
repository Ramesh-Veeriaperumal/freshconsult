class CustomFieldsController < Admin::AdminController

  include Helpdesk::Ticketfields::ControllerMethods
  include Cache::FragmentCache::Base
  include Helpdesk::CustomFields::CustomFieldMethods
  include Cache::Memcache::Helpdesk::Section
  include FlexifieldConstants
  include Helpdesk::Ticketfields::Validations

  before_filter :check_ticket_field_count, :only => [ :update ]
  helper_method :denormalized_field?

  SECTION_ACTIONS = ["save", "delete"]
  SECTION_TYPE = ["existing", "new"]
  TICKET_FIELD_ACTIONS = ['delete', 'edit', 'create']
  FLEXIFIELD_PREFIXES = ['ffs', 'ff_text', 'ff_int', 'ff_date', 'ff_boolean', 'ff_decimal']

  def update #To Do - Sending proper status messages to UI.

    @invalid_fields = []
    @invalid_sections = []
    @fields_id_with_sections = []

    if (params[:jsonSectionData] && params[:jsonSectionData].length >= 2)
      sections_data = ActiveSupport::JSON.decode params[:jsonSectionData]
      if current_account.multi_dynamic_sections_enabled?
        @fields_id_with_sections = fetch_fields_with_sections(sections_data)
      end
    end

    field_data_group_by_action = field_data.group_by { |f_d| f_d["action"] }
    TICKET_FIELD_ACTIONS.each do |action|
      next if action == "create" && !current_account.custom_ticket_fields_enabled?
      field_data_group_by_action[action].each do |f_d|
        f_d.symbolize_keys!
        # f_d.delete(:choices) unless("nested_field".eql?(f_d[:field_type]) || 
        #                             "custom_dropdown".eql?(f_d[:field_type]) || 
        #                             "default_ticket_type".eql?(f_d[:field_type]))
        f_d[:field_options].delete("section_present") if delete_section_present_key? f_d
        safe_send("#{action}_field", f_d)
      end
    end

    # adding sections data...
    sections_attributes(sections_data)

    unless @invalid_sections.empty?
      @invalid_sections.each do |field|
        field.symbolize_keys!
        reset_section_fields(field[:section_fields]) unless field[:section_fields].nil?
        delete_section_data(account=current_account, field)
        reset_parent_field(field[:parent_ticket_field_id])
      end
    end

    err_str = ""
    @invalid_fields.each do |tf|
      tf.errors.each do |attr,msg|
        if(!err_str.include? "#{tf.label} : #{msg}")
          err_str << " #{tf.label} : #{msg} "
        end  
      end  
    end
    clear_fragment_caches
    err_str = err_str.to_s.html_safe
    flash_message(err_str)
    expire_cache
    response_data = current_portal.ticket_fields_including_nested_fields if err_str.blank?
    invoke_respond_to(err_str, response_data.presence) do
      redirect_to :action => :index
    end
  end

  private

    def delete_section_present_key? field
      current_account.multi_dynamic_sections_enabled? && !@fields_id_with_sections.include?(field[:id]) &&
      Helpdesk::TicketField::SECTION_DROPDOWNS.include?(field[:field_type]) &&
      field[:field_options].present?
    end

    def edit_field(field_details)
      #Length(current: 4) has to be updated if any default status is added or deleted
      if field_details[:field_type] == "default_status" && !current_account.custom_ticket_fields_enabled? && field_details[:choices].length > 4
        field_details[:choices].reject!{ |choice| !choice["status_id"].present? }
      end
      field_details.delete(:type)
      field_details.delete(:dom_type)
      custom_field = scoper.find(field_details.delete(:id))
      nested_fields = field_details.delete(:levels)
      unless custom_field.update_attributes(field_details)
        Rails.logger.debug "Ticket field update failed : #{current_account.id} 
                            #{custom_field.id} #{custom_field.label} 
                            #{custom_field.errors.messages}"
        @invalid_fields.push(custom_field)
        # To allow the ticket field's field_options to have section_present key
        # when a section/section field is associated but the validation fails
        # for a ticket field
        custom_field.reload
        field_options = field_details[:field_options]
        unless custom_field.field_options == field_options
          custom_field.update_attribute(:field_options, field_options)
        end
      end
      if custom_field.field_type == "nested_field"
        (nested_fields || []).each do |nested_field|
          nested_field.symbolize_keys!
          nested_field[:action] ||= 'edit'
          action = nested_field.delete(:action)
          if action == "create"
            nested_ff_def_entry = FlexifieldDefEntry.new ff_meta_data(nested_field, Account.current)
            is_saved = create_nested_field(nested_ff_def_entry, custom_field, nested_field.merge(type: "nested_field"))
            construct_child_levels(nested_ff_def_entry, custom_field, nested_field) if is_saved
          else
            safe_send("#{action}_nested_field", custom_field, nested_field)
          end
        end
      end
    end

    def expire_cache
      current_account.clear_required_ticket_fields_cache
      current_account.clear_section_parent_fields_cache
      clear_all_section_ticket_fields_cache
    end

    def delete_field(field_details)
      f_to_del = scoper.find field_details[:id]
      f_to_del.destroy if f_to_del
      Rails.logger.debug "Ticket field deletion :: A :: #{Account.current.id} TF :: #{f_to_del.id} TF name :: #{f_to_del.label} #{f_to_del.name} U :: #{User.current.id} :: #{f_to_del}"
    end

    def flash_message(err_str)
      unless err_str.empty?
        flash[:error] = err_str
      else
        flash[:notice] = t(:'flash.custom_fields.update.success')
      end
    end

    def fetch_fields_with_sections sections_data
      parent_field_ids, del_sections, curr_sections = {}, {}, {}
      parent_field_ids[SECTION_TYPE[0]], parent_field_ids[SECTION_TYPE[1]] = [], []
      current_account.ticket_fields_from_cache .each do |field| 
        if Helpdesk::TicketField::SECTION_DROPDOWNS.include?(field.field_type) &&
            field.field_options && field.field_options["section_present"]
          parent_field_ids[SECTION_TYPE[0]].push(field.id)
        end
      end
      sections_data.each do |sec|
        sec.symbolize_keys!
        parent_field_id = sec[:parent_ticket_field_id].to_i
        if sec[:id].present?
          if sec[:action] == SECTION_ACTIONS[1]
            del_sections[parent_field_id] ||= []
            del_sections[parent_field_id].push(sec[:id])
          else
            curr_sections[parent_field_id] ||= []
            curr_sections[parent_field_id].push(sec[:id])
            parent_field_ids[SECTION_TYPE[0]].push(parent_field_id) if valid_section?(parent_field_ids,parent_field_id)
          end
        elsif sec[:action] == SECTION_ACTIONS[0]
          parent_field_ids[SECTION_TYPE[1]].push(parent_field_id) if valid_section?(parent_field_ids, parent_field_id)
        end
      end
      del_sections.each do |tf_id|
        parent_field_ids[SECTION_TYPE[0]].delete(tf_id[0]) if curr_sections[tf_id[0]].blank?
      end
      (parent_field_ids[SECTION_TYPE[0]] | parent_field_ids[SECTION_TYPE[1]])[0..Helpdesk::TicketField::SECTION_LIMIT-1]
    end

    def valid_section?(parent_field_ids, parent_field_id)
      combined_parent_field_ids = (parent_field_ids[SECTION_TYPE[0]] | parent_field_ids[SECTION_TYPE[1]])
      !combined_parent_field_ids.include?(parent_field_id)
    end

    def invalid_section? sec
      return unless current_account.multi_dynamic_sections_enabled?
      unless @fields_id_with_sections.include?(sec[:parent_ticket_field_id].to_i)
        if sec[:id].nil?
          reset_section_fields(sec[:section_fields]) unless sec[:section_fields].nil?
        else
          @invalid_sections.push(sec)
        end
        true
      end
    end

    def field_data
      @field_data ||= begin
        ActiveSupport::JSON.decode(params[:jsonData]).compact
      end
    end

    def custom_field_data
      custom_field_data ||= begin
        field_data.reject { |f_d| f_d["field_type"].include?("default_") }
      end
    end

    def denormalized_field? column_name
      !(FLEXIFIELD_PREFIXES.any? { |col_prefix| column_name.to_s.include?(col_prefix) })
    end

    # Section related changes - start

    def sections_attributes(sec_params,account=current_account)
      sec_params.each do |sec|
        sec.symbolize_keys!
        if (action = sec.delete(:action)).present? && SECTION_ACTIONS.include?(action)
          safe_send("#{action}_section_data",account,sec) 
        else
          invalid_section? sec
        end
      end
    end

    def find_section(account, id)
      account.sections.find_by_id(id)
    end

    def save_section_data(account,sec)
      return if invalid_section?(sec)
      section = sec[:id].nil? ? account.sections.build : find_section(account, sec[:id])
      section.label = sec[:label]
      build_section_picklist_mappings(section, 
                                      sec[:picklist_ids],
                                      sec[:parent_ticket_field_id].to_i,
                                      account) unless sec[:picklist_ids].nil?
      return unless section.section_picklist_mappings.present?
      build_section_fields(account,
                           section,
                           sec[:section_fields]) unless sec[:section_fields].nil?
      section.save
    end

    def build_section_picklist_mappings(section, picklist_ids, ticket_field_id, account)
      # We don't get the id of the picklist_mapping from the UI
      # We only get [{:picklist_value_id => 1}, {:picklist_value_id => 2}]
      # Supposedly, since it increases load on the browser
      # Need to change
      ticket_field = account.ticket_fields.find_by_id(ticket_field_id)
      pl_values = ticket_field.picklist_values.map(&:id)
      pl_mappings = section.section_picklist_mappings
      db_ids = pl_mappings.map(&:picklist_value_id)
      ui_ids = picklist_ids.map {|p| p["picklist_value_id"].to_i}
      (ui_ids - db_ids).each do |id|
        section.section_picklist_mappings.build(:picklist_value_id => id) if pl_values.include?(id)
      end
      (db_ids - ui_ids).each do |id|
        pl_val = pl_mappings.find { |p| p.picklist_value_id == id }
        pl_val.destroy if pl_val
      end
    end

    def build_section_fields(account,section,section_fields)
      sec_fields = section.section_fields
      section_fields.each do |sec_field|
        sec_field.symbolize_keys!
        if sec_field[:action] == "delete"
          field = find_section_association(sec_fields, sec_field[:id])
          field.destroy if field
        elsif sec_field[:id].nil?
          ticket_field_name = sec_field.delete(:ticket_field_name)
          is_encrypted = sec_field.delete(:is_encrypted) 
          if sec_field[:ticket_field_id].nil?
            alias_name = field_name(ticket_field_name, account, is_encrypted)
            invalid_field = @invalid_fields.find { |f| f.name == alias_name && f.section_field? }
            # When multiple fields with same name are saved, we'll save the last field and not the first. 
            if invalid_field.present?
              index = @invalid_fields.index(invalid_field)
              invalid_field.field_options["section"] = false
              @invalid_fields[index] = invalid_field
              next
            end
            field_id = tkt_field_id_alias_hash(account)[alias_name]
            sec_field[:ticket_field_id] = field_id
          end
          section.section_fields.build(sec_field) if sec_field[:ticket_field_id].present? && 
                      !sec_fields.map(&:ticket_field_id).include?(sec_field[:ticket_field_id])
        elsif (field = find_section_association(sec_fields, sec_field[:id]))
          field.position = sec_field[:position]
        end
      end
    end

    def find_section_association(association, id)
      association.find { |a| a.id == id }
    end

    def tkt_field_id_alias_hash(account)
      @tkt_field_id_alias_hash ||= account.ticket_fields.reject {|f| f.id.nil?}.inject({}) do |r,h|
        r[h.name] = h.id
        r
      end 
    end

    def delete_section_data(account,sec)
      section = find_section(account, sec[:id])
      section.destroy unless section.nil?
    end

    def reset_parent_field(field)
      return unless field.section_fields.blank?
      if field.field_options["section_present"]
        field.field_options["section_present"] = false
        field.save
      end
    end

    def reset_section_fields(section_fields, account=current_account)
      section_fields.each do |sec_field|
        sec_field.symbolize_keys!
        if sec_field[:ticket_field_id].nil?
          ticket_field_name = sec_field.delete(:ticket_field_name)
          alias_name = field_name(ticket_field_name, account)
          field_id = tkt_field_id_alias_hash(account)[alias_name]
        else
          field_id = sec_field[:ticket_field_id]
        end
        field = account.ticket_fields.find_by_id(field_id)
        field.rollback_section_in_field_options
      end
    end
    # Section related changes - end

    def denormalized_flexifields_enabled?
      @denormalized_flexifields_enabled ||= Account.current.denormalized_flexifields_enabled?
    end

    def ticket_field_limit_increase_enabled?
      @ticket_field_limit_increase_enabled ||= Account.current.ticket_field_limit_increase_enabled?
    end
end

class CustomFieldsController < Admin::AdminController

  include Import::CustomField

  before_filter :check_ticket_field_count, :only => [ :update ]
  
  MAX_ALLOWED_COUNT = { 
    :string => 80,
    :text => 10,
    :number => 20,
    :date => 10,
    :boolean => 10,
    :decimal => 10
  }

  def update #To Do - Sending proper status messages to UI.

    @invalid_fields = []
    @field_data.each_with_index do |f_d, i|
      f_d.symbolize_keys!

      unless (action = f_d.delete(:action)).nil?
        # f_d.delete(:choices) unless("nested_field".eql?(f_d[:field_type]) || 
        #                             "custom_dropdown".eql?(f_d[:field_type]) || 
        #                             "default_ticket_type".eql?(f_d[:field_type]))
        send("#{action}_field", f_d)
      end
    end

    # adding sections data...
    if (params[:jsonSectionData] && params[:jsonSectionData].length >= 2)
      sections_data = ActiveSupport::JSON.decode params[:jsonSectionData]
      sections_attributes(sections_data)
    end

    err_str = ""
    @invalid_fields.each do |tf|
        tf.errors.each do |attr,msg|
          if(!err_str.include? "#{tf.label} : #{msg}")
            err_str << " #{tf.label} : #{msg} "
          end  
        end  
    end
    flash_message(err_str.to_s.html_safe)
    redirect_to :action => :index
  end

  private

    def edit_field(field_details)
      field_details.delete(:type)
      field_details.delete(:dom_type)
      custom_field = scoper.find(field_details.delete(:id))
      nested_fields = field_details.delete(:levels)
      unless custom_field.update_attributes(field_details)
        @invalid_fields.push(custom_field)
      end
      if custom_field.field_type == "nested_field"
        (nested_fields || []).each do |nested_field|
          nested_field.symbolize_keys!
          nested_field[:action] ||= 'edit'
          action = nested_field.delete(:action)
          send("#{action}_nested_field", custom_field, nested_field)
        end
      end
    end

    def delete_field(field_details)
      f_to_del = scoper.find field_details[:id]
      f_to_del.destroy if f_to_del
    end

    def flash_message(err_str)
      unless err_str.empty?
        flash[:error] = err_str
      else
        flash[:notice] = t(:'flash.custom_fields.update.success')
      end
    end

    def check_ticket_field_count
      field_data_group = custom_field_data.group_by { |c_f_d| c_f_d["type"]}
      field_data_count_by_type = {
                                :string =>  calculate_string_fields_count(field_data_group),
                                :text => field_data_group["paragraph"].length,
                                :number => field_data_group["number"].length,
                                :boolean => field_data_group["checkbox"].length,
                                :decimal => field_data_group["decimal"].length
                                }
      error_str = ""
      field_data_count_by_type.keys.each do |key|
        if field_data_count_by_type[key] > MAX_ALLOWED_COUNT[key]
          error_str << I18n.t("flash.custom_fields.failure.#{key}")
        end
      end
      unless error_str.blank?
        flash[:error] = error_str 
        redirect_to :back and return
      end
    end

    def custom_field_data
      @field_data = ActiveSupport::JSON.decode params[:jsonData]
      @field_data.reject { |f_d| f_d["field_type"].include?("default_") }.compact
    end

    def calculate_string_fields_count field_data_group
      field_data_group["dropdown"].length + field_data_group["text"].length + 
                (field_data_group["dropdown"] || []).map{|x| x["levels"]}.flatten.compact.length
    end

    # Section related changes - start

    def sections_attributes(sec_params,account=current_account)
      sec_params.each do |sec|
        sec.symbolize_keys!
        if (action = sec.delete(:action)).present? && ["save", "delete"].include?(action)
          send("#{action}_section_data",account,sec)
        end
      end
    end

    def find_section(account, id)
      account.sections.find_by_id(id)
    end

    def save_section_data(account,sec)
      section = sec[:id].nil? ? account.sections.build : find_section(account, sec[:id])
      section.label = sec[:label]
      build_section_picklist_mappings(section, 
                                      sec[:picklist_ids],
                                      account) unless sec[:picklist_ids].nil?
      return unless section.section_picklist_mappings.present?
      build_section_fields(account,
                           section,
                           sec[:section_fields]) unless sec[:section_fields].nil?
      section.save
    end

    def build_section_picklist_mappings(section,picklist_ids, account)
      # We don't get the id of the picklist_mapping from the UI
      # We only get [{:picklist_value_id => 1}, {:picklist_value_id => 2}]
      # Supposedly, since it increases load on the browser
      # Need to change
      pl_values = account.ticket_fields.find_by_field_type("default_ticket_type").picklist_values.map(&:id)
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
          if sec_field[:ticket_field_id].nil?
            alias_name = field_name(ticket_field_name, account)
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
    # Section related changes - end
end

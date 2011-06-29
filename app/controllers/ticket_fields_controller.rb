class TicketFieldsController < Admin::AdminController
  
  FIELD_COLUMN_MAPPING = {
    "text"      => [["text" , "dropdown"], Helpdesk::FormCustomizer::CHARACTER_FIELDS],
    "dropdown"  => [["text" , "dropdown"], Helpdesk::FormCustomizer::CHARACTER_FIELDS],
    "number"    => ["number", Helpdesk::FormCustomizer::NUMBER_FIELDS],
    "checkbox"  => ["checkbox", Helpdesk::FormCustomizer::CHECKBOX_FIELDS],
    "date"      => ["date", Helpdesk::FormCustomizer::DATE_FIELDS],
    "paragraph" => ["paragraph", Helpdesk::FormCustomizer::TEXT_FIELDS]
  }
  
  def index
    @ticket_fields = scoper.find(:all)
    @ticket_field_json = @ticket_fields.map do |field|      
        { :field_type             => field.field_type,
          :id                     => field.id,
          :name                   => field.name,
          :label                  => field.label,
          :label_in_portal        => field.label_in_portal,
          :description            => field.description,
          :field_type             => field.field_type,
          :position               => field.position,
          :active                 => field.active,
          :required               => field.required,
          :required_for_closure   => field.required_for_closure,
          :visible_in_portal      => field.visible_in_portal,
          :editable_in_portal     => field.editable_in_portal,
          :required_in_portal     => field.required_in_portal,
          :choices                => field.choices }
    end 
    
    respond_to do |format|
      format.html # index.html.erb
      #format.xml  { render :xml => @ticket_fields.agent_view } #To Do Shan..
    end
  end

  def update #To Do - Sending proper status messages to UI.
    field_data = ActiveSupport::JSON.decode params[:jsonData]
    field_data.each_with_index do |f_d, i|
      f_d.symbolize_keys!
    
      unless f_d[:position] && (f_d[:position] == (i+1))
        f_d[:position] = i+1
        f_d[:action] ||= 'edit'
      end
      
      unless (action = f_d.delete(:action)).nil?
        f_d.delete(:choices) unless "custom_dropdown".eql?(f_d[:field_type])
        send("#{action}_field", f_d) 
      end
    end

    redirect_to :action => :index 
  end
  
  def old_code
    respond_to do |format|
      if @ticket_field.update_attributes(:json_data =>modified_json, :agent_view =>@agentView,
              :requester_view => requester_json )   
          flash[:notice] = t(:'flash.custom_fields.update.success')
          format.html { redirect_to :action => "index" }
          format.xml  { render :json => @ticket_field }     
      else  
          flash[:notice] = t(:'flash.custom_fields.update.failure')
          format.html { redirect_to :action => "index"}
          format.xml  { render :json => @ticket_field } 
      end
    end
  end

  protected
    def scoper
      current_account.ticket_fields
    end
    
  private
    def create_field(field_details)
      ff_def_entry = FlexifieldDefEntry.new ff_meta_data(field_details)
      if ff_def_entry.save
        field_details.delete(:id)
        ticket_field = scoper.build(field_details)
        ticket_field.name = ff_def_entry.flexifield_alias
        ticket_field.flexifield_def_entry_id = ff_def_entry.id
        ticket_field.save! # Remove the !
      end
    end
    
    def ff_meta_data(field_details)
      type = field_details.delete(:type)
      ff_def = current_account.flexi_field_defs.first
      ff_def_entries = ff_def.flexifield_def_entries.all(:conditions => { 
        :flexifield_coltype => FIELD_COLUMN_MAPPING[type][0] })

      used_columns = ff_def_entries.collect { |ff_entry| ff_entry.flexifield_name }
      available_columns = FIELD_COLUMN_MAPPING[type][1] - used_columns
      
      { 
        :flexifield_def_id => ff_def.id, 
        :flexifield_name => available_columns.first,
        :flexifield_coltype => type, 
        :flexifield_alias => field_name(field_details[:label]), 
        :flexifield_order => field_details[:position] #ofc. there'll be gaps.
      }
    end
    
    def field_name(label)
      label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase
    end
    
    def edit_field(field_details)
      field_details.delete(:type)
      scoper.find(field_details.delete(:id)).update_attributes(field_details)
    end
    
    def delete_field(field_details)
      f_to_del = scoper.find field_details[:id]
      f_to_del.destroy if f_to_del
    end

end

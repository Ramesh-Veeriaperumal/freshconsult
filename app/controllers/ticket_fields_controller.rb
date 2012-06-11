class TicketFieldsController < Admin::AdminController
  include Import::CustomField
  
  def index
    @ticket_fields = current_portal.ticket_fields
    
    respond_to do |format|
      format.html { 
        @ticket_field_json = @ticket_fields.map do |field|      
          { :field_type             => field.field_type,
            :id                     => field.id,
            :name                   => field.name,
            :dom_type               => field.dom_type,
            :label                  => ( field.is_default_field? ) ? I18n.t("ticket_fields.fields.#{field.name}") : field.label,
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
            :choices                => get_choices(field),
            :levels                 => field.levels,
            :level_three_present    => field.level_three_present
          }
          
    end 
      }
      format.xml  { render :xml => @ticket_fields.to_xml } 
      format.json  { render :json => Hash.from_xml(@ticket_fields.to_xml) } 
    end
  end

  def update #To Do - Sending proper status messages to UI.

    @invalid_fields = []
    field_data = ActiveSupport::JSON.decode params[:jsonData]
    field_data.each_with_index do |f_d, i|
      f_d.symbolize_keys!
    
      unless f_d[:position] && (f_d[:position] == (i+1))
        f_d[:position] = i+1
        f_d[:action] ||= 'edit'
      end
      
      unless (action = f_d.delete(:action)).nil?
#        f_d.delete(:choices) unless("nested_field".eql?(f_d[:field_type]) || "custom_dropdown".eql?(f_d[:field_type]) || "default_ticket_type".eql?(f_d[:field_type]))
        send("#{action}_field", f_d) 
      end
    end
    
    err_str = ""
    @invalid_fields.each do |tf|
      tf.errors.each { |attr,msg| err_str << " #{tf.label} : #{msg} <br />"  }
    end
     
    unless err_str.empty?
      flash[:error] = err_str
    else
      flash[:notice] = t(:'flash.custom_fields.update.success')
    end
     
    redirect_to :action => :index
  end
  
  protected
    def scoper
      current_account.ticket_fields
    end
    
  private
    def edit_field(field_details)
      field_details.delete(:type)
      field_details.delete(:dom_type)
      ticket_field = scoper.find(field_details.delete(:id))
      nested_fields = field_details.delete(:levels) 
      unless ticket_field.update_attributes(field_details)
        @invalid_fields.push(ticket_field) 
      end
      if ticket_field.field_type == "nested_field"
        (nested_fields || []).each do |nested_field|
          nested_field.symbolize_keys!
          nested_field[:action] ||= 'edit'
          action = nested_field.delete(:action)
          send("#{action}_nested_field", ticket_field, nested_field) 
        end
      end
    end

    def get_choices(field)
      case field.field_type
        when "nested_field" then
          field.nested_choices
        when "default_status" then
          Helpdesk::TicketStatus::statuses_list(current_account)
        else 
          field.choices
      end
    end
    
    def delete_field(field_details)
      f_to_del = scoper.find field_details[:id]
      f_to_del.destroy if f_to_del
    end

    def edit_nested_field(ticket_field,nested_field)
      nested_field.delete(:type)
      nested_field.delete(:position)
      nested_ticket_field = ticket_field.nested_ticket_fields.find(nested_field.delete(:id))
      @invalid_fields.push(ticket_field) and return unless nested_ticket_field.update_attributes(nested_field)
    end

    def delete_nested_field(ticket_field,nested_field)
      nested_ticket_field = ticket_field.nested_ticket_fields.find(nested_field[:id])
      nested_ticket_field.destroy if nested_ticket_field
    end
end

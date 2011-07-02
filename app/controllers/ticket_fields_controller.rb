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
        f_d.delete(:choices) unless "custom_dropdown".eql?(f_d[:field_type])
        send("#{action}_field", f_d) 
      end
    end
    
    err_str = ""
    @invalid_fields.each do |tf|
      tf.errors.each { |attr,msg| err_str << " #{tf.label}  #{attr} #{msg} <br />"  }
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
      unless ticket_field.update_attributes(field_details)
        @invalid_fields.push(ticket_field) 
      end
    end
    
    def delete_field(field_details)
      f_to_del = scoper.find field_details[:id]
      f_to_del.destroy if f_to_del
    end

end

class CustomFieldsController < Admin::AdminController

  include Import::CustomField

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
        tf.errors.each do |attr,msg|
          if(!err_str.include? "#{tf.label} : #{msg}")
            err_str << " #{tf.label} : #{msg} <br />"
          end  
        end  
    end
    flash_message(err_str)
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
end

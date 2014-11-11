class CustomFieldsController < Admin::AdminController

  include Import::CustomField

  before_filter :check_ticket_field_count, :only => [ :update ]
  
  MAX_ALLOWED_COUNT = { 
    :string => 80,
    :text => 10,
    :number => 20,
    :date => 10,
    :boolean => 10
  }

  def update #To Do - Sending proper status messages to UI.

    @invalid_fields = []
    @field_data.each_with_index do |f_d, i|
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
                              :boolean => field_data_group["checkbox"].length 
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
end

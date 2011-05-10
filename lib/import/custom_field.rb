module Import::CustomField
  


def import_flexifields base_dir
  
  file_path = File.join(base_dir , "ticket_fields.xml")
  created = 0
  updated = 0
  file = File.new(file_path) 
  doc = REXML::Document.new file
    
  REXML::XPath.each(doc,'//record') do |record|    
    
     field_type = nil
     cat_desc = nil
     import_id = nil
     title = nil
     agent_closure = false
     cust_rqrd = false
     cust_visible = false
     cust_editable = false
     
     
     record.elements.each("type") do |type|      
       field_type = type.text         
     end
     
     record.elements.each("title") do |title|      
       title = title.text         
     end
     
     logger.debug "The record title is  ::: #{title}"
     
     record.elements.each("id") do |obj_id|      
       import_id = obj_id.text         
     end
     
     record.elements.each("is-required") do |required|      
       agent_closure = required.text         
     end
     
     record.elements.each("is-required-in-portal") do |cust_rq|      
       cust_rqrd = cust_rq.text         
     end
     
     record.elements.each("is-visible-in-portal") do |cust_view|      
       cust_visible = cust_view.text         
     end
     
     record.elements.each("is-editable-in-portal") do |cust_edit|      
       cust_editable = cust_edit.text         
     end
     
     field_prop = Hash.new
     field_prop["display_name"] = title     
     field_prop["agent_rqrd"] = agent_closure
     field_prop["cust_rqrd"] = cust_rqrd
     field_prop["cust_visible"] = cust_visible
     field_prop["cust_editable"] = cust_editable
     
     label = title.gsub('?','')+"_"+current_account.id.to_s()
     label = label.gsub(/\s+/,"_")
     
     ff_id =FlexifieldDef.first(:conditions =>{:account_id => current_account.id}).id  
     @flexifield =FlexifieldDefEntry.find_by_import_id_and_flexifield_def_id(import_id,ff_id)
     next unless @flexifield.blank? 
     
     case field_type
       
     when "FieldCheckbox"
          type = "checkbox"      
          column_id = save_custom_field label , type , import_id
          field_prop["label"] = label
          field_prop["type"] = type
          unless column_id == -1
            update_form_customizer field_prop, column_id
          end
         
     when "FieldText"
          
          type = "text"
          column_id = save_custom_field label , type , import_id
          field_prop["label"] = label
          field_prop["type"] = type
          unless column_id == -1
              update_form_customizer field_prop, column_id  
          end
     when "FieldTagger"
          
          type = "dropdown"
          column_id = save_custom_field label , type , import_id
          
          choices = Array.new
          record.elements.each("custom-field-options/custom-field-option") do |options| 
            option_val =nil
            tag_val = []
            select_option = Hash.new
            options.elements.each("name") { |name| option_val =  name.text }  
            options.elements.each("value") { |value| tag_val =  value.text }   
            select_option["tags"]=tag_val
            select_option["value"]=option_val
            choices.push(select_option)
         end
          field_prop["type"] = type
          field_prop["label"] = label
          unless column_id == -1
              update_form_customizer field_prop, column_id,choices
          end
     when "FieldInteger"
          
          type = "number"
          column_id = save_custom_field label , type , import_id
          field_prop["type"] = type
          field_prop["label"] = label
          unless column_id == -1
              update_form_customizer field_prop, column_id  
          end
     when "FieldTextarea"
          
          type = "paragraph"
          column_id = save_custom_field label , type , import_id
          field_prop["type"] = type
          field_prop["label"] = label
          unless column_id == -1
              update_form_customizer field_prop, column_id
          end
     else
          logger.debug "None of the field type matches:: hope its a system field"
     end
       
     
    end
  
end


def get_new_column_details type
  
 
  data = Hash.new 
  
  ff_def_id =FlexifieldDef.first(:conditions =>{:account_id => current_account.id}).id
  
  @flexifield_def_entries = FlexifieldDefEntry.all(:conditions =>{:flexifield_def_id => ff_def_id ,:flexifield_coltype => type})
  
  logger.debug "here is the inspection #{@flexifield_def_entries.inspect}"
   
  @coulumn_used = []
   
  ff_order = 0
    
  @flexifield_def_entries.each do |entry|
      @coulumn_used.push(entry.flexifield_name) 
      
      ff_order = entry.flexifield_order
      
      end
 
   logger.debug "current occupaid columsn : #{@coulumn_used.inspect}"
     
     
  @column_exist = nil
    
  new_column = nil
 
  case type
    
  when ["text" , "dropdown"]
    
    @column_list = Helpdesk::FormCustomizer::CHARACTER_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
  when "number"
    
    @column_list = Helpdesk::FormCustomizer::NUMBER_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
    
  when "checkbox"
    
    @column_list = Helpdesk::FormCustomizer::CHECKBOX_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
  when "date"
    
    @column_list = Helpdesk::FormCustomizer::DATE_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
 when "paragraph"
    
    @column_list = Helpdesk::FormCustomizer::TEXT_FIELDS
    
    @column_exist = @column_list - @coulumn_used
    
    logger.debug "current exist : #{@column_exist.inspect}"
    
    new_column = @column_exist[0]
    
    logger.debug "new columns : #{new_column}"
    
    
  end
  
  data ={"ff_def_id" =>ff_def_id, "ff_order" => ff_order,"column_name" =>new_column}
  
  return data
  

end

def update_form_customizer field_prop, column_id, choices=[]
  @ticket_fields = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
  json_data = @ticket_fields.json_data
  @data = []
  @data = ActiveSupport::JSON.decode(json_data)
  req_view = @ticket_fields.requester_view
  @endUser = ActiveSupport::JSON.decode(req_view)
  
  cust_field = Hash.new  
  
  cust_field ={"label"=>field_prop["label"], "setDefault"=>0, "fieldType"=>"custom", 
                "action"=>"edit", "type"=>field_prop["type"], "agent"=>{"required"=>true, "closure"=>field_prop["agent_rqrd"]}, 
                "styleClass"=>"", "display_name"=>field_prop["display_name"], "description"=>"",
                "customer"=>{"required"=>field_prop["cust_rqrd"] , "editable"=>field_prop["cust_editable"], "visible"=>field_prop["cust_visible"]}, 
                "columnId"=>column_id, "choices"=>choices}
                
   @data.push(cust_field)
   
   
    if field_prop["cust_visible"].eql?(true)      
      @endUser.push(cust_field) 
    end
   
    modified_json = ActiveSupport::JSON.encode(@data)
    requester_json = ActiveSupport::JSON.encode(@endUser)
    logger.debug "@data :: before updating :: #{@data.inspect}"
    if @ticket_fields.update_attributes(:json_data =>modified_json, :agent_view =>@data , :requester_view => requester_json )  
       logger.debug "Custom fields successfully updated."     
    else  
       logger.debug "Custom updation failed."
    end
  
end

def save_custom_field ff_alias , column_type , import_id
  
  coltype ="text"
  
  if ("dropdown".eql?(column_type) || "text".eql?(column_type))
    coltype = ["text" , "dropdown"]
  else
    coltype = column_type
  end
  
  columnId = 0
  
  data = get_new_column_details coltype
  
  column_name = data["column_name"]
  
  ff_def_id = data["ff_def_id"]
  
  ff_order = data["ff_order"]
  
  logger.debug "type is #{column_type} and new_column#{column_name} and ff_def_id : #{ff_def_id} and ff_alias:: #{ff_alias.inspect} "
  
  #saving new column as Untitled
  
  @ff_entries = FlexifieldDefEntry.new(:flexifield_name =>column_name , :flexifield_def_id =>ff_def_id ,:flexifield_alias =>ff_alias , :flexifield_order =>ff_order +1, :flexifield_coltype =>column_type ,:import_id =>import_id.to_i())
 
  
  if @ff_entries.save    
     columnId = @ff_entries.id     
   else    
     logger.debug "error while saving the cusom field #{ff_alias} : Error:: #{@ff_entries.errors.inspect}"
     columnId = -1    
  end
  logger.debug "columnId inside  save methode :: #{columnId}"
  
  return columnId
  
end

end
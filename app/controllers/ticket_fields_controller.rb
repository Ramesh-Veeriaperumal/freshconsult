class TicketFieldsController < Admin::AdminController
   
  def index
    
    @ticket_fields = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @ticket_fields }
    end
    
  end
  
  #Following method will create first entry for each account
  #

  def create 
    
   @ticket_field = Helpdesk::FormCustomizer.new
   
   data = Helpdesk::FormCustomizer::DEFAULT_FIELDS_JSON
   
   @ticket_field.name = "Ticket_"+current_account.id.to_s()
   
   @ticket_field.json_data = data
   
   @ticket_field.account_id = current_account.id
   
   if @ticket_field.save
      render :text => "successfully saved"
     
   else
     
      render :text => "Oops...Unable to save", :status => "500"

   end
   
   
end

def update
  
  jsonData = params[:jsonData]
  
  @data = ActiveSupport::JSON.decode(jsonData)  
  
  @endUser =[]
  
  @agentView =[]
  
  @data.each do |key|
    logger.debug "key: #{key.inspect}"
    logger.debug "label :: #{key["label"]}"
    logger.debug "columnId :: #{key["columnId"]}"
    logger.debug "fieldType :: #{key["fieldType"]}"
    
    logger.debug "action action :: #{key["action"]}"
        
    columnId = 0
    if key["fieldType"].eql?("custom")
      
      if key["action"].eql?("delete")     
        delete_custom_fields key["columnId"]      
      elsif key["columnId"].eql?("")
        #Add the new column
        columnId = save_flexi_field_entries key["label"], key["type"]
        logger.debug "columnId after saving :: #{columnId}"        
        if columnId == -1 then
            next
        end
        
        key["columnId"] = columnId
      else
        #update flexifields
        columnId = key["columnId"]
        update_flexi_field_entries columnId, key["label"], key["type"]
      end
      
    end   
   
      #setting the new columnId to array and pushing to new array
      
    unless key["action"].eql?("delete")    
     @agentView.push(key)    
    end
    
   logger.debug "Agent View #{@agentView.inspect}" 
    #Following code will generate a seperate view for end customers
    
    if key["customer"]["visible"].eql?(true)
      #logger.debug "yeah this field is visible"
      @endUser.push(key) unless key["action"].eql?("delete")
    end
    
      logger.debug "endUser: #{@endUser.inspect}" 
   
end

  #here its going to update the database-- encode as json and then store it
  
   modified_json = ActiveSupport::JSON.encode(@agentView)
   
   requester_json = ActiveSupport::JSON.encode(@endUser)
  
  @ticket_field = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
  
   res = Hash.new
   
  respond_to do |format|
    
  if @ticket_field.update_attributes(:json_data =>modified_json, :agent_view =>@agentView , :requester_view => requester_json )   
      flash[:notice] = "Custom fields successfully updated."
      format.html { redirect_to :action => "index" }
      format.xml  { render :json => @ticket_field }     
  else  
      flash[:notice] = "Custom updation failed."
      format.html { redirect_to :action => "index"}
      format.xml  { render :json => @ticket_field } 
  
  end
  
  end
  ##Need to pass back the modified_json and reload it after saving...
  
  
end

def delete_custom_fields columnId
  unless columnId.nil?
    @flexifield_def = FlexifieldDefEntry.find(columnId)
    @flexifield_def.destroy
    
  end
end
def save_flexi_field_entries ff_alias, ff_type
  
  coltype ="text"
  
  if ("dropdown".eql?(ff_type) || "text".eql?(ff_type))
    coltype = ["text" , "dropdown"]
  else
    coltype = ff_type
  end
  
  columnId = 0
  
  data = get_new_column_details coltype
  
  column_name = data["column_name"]
  
  ff_def_id = data["ff_def_id"]
  
  ff_order = data["ff_order"]
  
  logger.debug "type is #{ff_type} and new_column#{column_name} and ff_def_id : #{ff_def_id} and ff_alias:: #{ff_alias.inspect} "
  
  #saving new column as Untitled
  
  @ff_entries = FlexifieldDefEntry.new(:flexifield_name =>column_name , :flexifield_def_id =>ff_def_id ,:flexifield_alias =>ff_alias , :flexifield_order =>ff_order +1, :flexifield_coltype =>ff_type)
 
  
  if @ff_entries.save    
     columnId = @ff_entries.id     
   else    
     logger.debug "error while saving the cusom field #{ff_alias} : Error:: #{@ff_entries.errors.inspect}"
     columnId = -1    
  end
  logger.debug "columnId inside  save methode :: #{columnId}"
  
  return columnId
  
  
end

def update_flexi_field_entries columnId, ff_alias, ff_type
  
  @flexifield_def = FlexifieldDefEntry.find(columnId)
  
  @flexifield_def.update_attributes(:flexifield_alias => ff_alias , :flexifield_coltype =>ff_type )   
  
  #logger.debug "type is #{type} and new_column#{new_column} and ff_def_id : #{ff_def_id} "
  
  
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
 

end

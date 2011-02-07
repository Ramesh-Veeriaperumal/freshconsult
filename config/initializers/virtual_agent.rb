
module VAConfig
  #  def self.prepare(params) 
  #    if params.is_a?(Hash)
  #      params.symbolize_keys!
  #      params.each { |k, v| params[k] = self.prepare(v) }
  #    end
  #    
  #    return params 
  #  end
  
  BUSINESS_RULE = 1
  SCENARIO_AUTOMATION = 2
  
  def self.handler(field,account_id)
    
    field_type = DEFAULT_FIELDS[field]
    
    if field_type.nil?
      field_type = check_for_custom_field field,account_id
    end
    
    RAILS_DEFAULT_LOGGER.debug " The field is : #{field} field_type is : #{field_type}"
    
    HANDLERS[field_type[:handler].to_sym]
    
  end
end

def check_for_custom_field field,account_id
 
  @ticket_field = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => account_id})
   
  @json_data = ActiveSupport::JSON.decode(@ticket_field.json_data)
   
    type = "text"
    
    @json_data.each do |ele| 
     
      if (field.to_s().eql?(ele["label"]))
        
          type = ele["type"]           
          RAILS_DEFAULT_LOGGER.debug " settingtype as  : #{type}"
          #exit 0 ;
      end
     
   end
  
    return type
   
end

YAML.load_file("#{RAILS_ROOT}/config/virtual_agent.yml").each do |k, v|
  VAConfig.const_set(k.upcase, Helpdesk::prepare(v))
end

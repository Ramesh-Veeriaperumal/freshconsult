class Helpdesk::FormCustomizer < ActiveRecord::Base
  
  serialize :json_data
  serialize :agent_view
  serialize :requester_view
   
  set_table_name "helpdesk_form_customizers"
   
  belongs_to :account
  attr_protected  :account_id
     
  DEFAULT_FIELDS_JSON = '[
                    { 
                      "fieldType": "default", 
                      "type": "text", 
                      "label": "Requester",
                      "display_name": "Requester", 
                      "description": "Enter requester name", 
                      "choices": [],  
                      "setDefault": 0, 
                      "agent": { "required": true },
                      "customer": { "visible": true, "editable": true, "required": true }
                    },
                       
                    {
                      "fieldType": "default", 
                      "type": "text",      
                      "label": "Subject",     
                      "display_name": "Subject",     
                      "description": "Request subject",           
                      "choices": [], 
                      "setDefault": 0, 
                      "agent": {"required": true}, 
                      "customer": {"visible": true, "editable": false, "required": true}
                    }, 
                    
                    {
                      "fieldType":"default", 
                      "type": "dropdown",  
                      "label": "Source",      
                      "display_name": "Source",      
                      "description": "Source of the request",     
                      "choices": [
                        {"value": "Staff initiated", "tags": []}, 
                        {"value": "E-mail", "tags": []}], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": false, "editable": false, "required": false}
                    },
                           
                    {
                      "fieldType":"default", 
                      "type": "dropdown",  
                      "label": "Type",        
                      "display_name": "Type",        
                      "description": "Type of the request",     
                      "choices": [
                        {"value": "How to", "tags": []}, 
                        {"value": "How to", "tags": []}], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": false, "editable": false, "required": false}
                    },
                                                  
                    {
                      "fieldType":"default", 
                      "type": "dropdown",  
                      "label": "Status",      
                      "display_name": "Status",      
                      "description": "Status of the request",     
                      "choices": [
                        {"value": "Open", "tags": []}, 
                        {"value": "Closed", "tags": []}], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": false, "editable": false, "required": false}
                    },
                     
                    {
                      "fieldType":"default", 
                      "type": "dropdown",  
                      "label": "Priority",    
                      "display_name": "Priority",    
                      "description": "",                          
                      "choices": [
                        {"value": "Low", "tags": []}, 
                        {"value": "High", "tags": []}],
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": false, "editable": false, "required": false}
                    },
                     
                    {
                      "fieldType":"default", 
                      "type": "dropdown",  
                      "label": "Group",       
                      "display_name": "Group",       
                      "description": "",                          
                      "choices": [
                        {"value": "Not Assigned", "tags": []}], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": false, "editable": false, "required": false}
                    },
                     
                    {
                      "fieldType":"default", 
                      "type": "dropdown",  
                      "label": "Assigned to", 
                      "display_name": "Assigned to", 
                      "description": "",                          
                      "choices": [
                        {"value": "Not Assigned", "tags": []}], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": false, "editable": false, "required": false}
                    }, 
                    
                    {
                      "fieldType":"default", 
                      "type": "paragraph", 
                      "label": "Description", 
                      "display_name": "Description", 
                      "description": "",                          
                      "choices": [], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": true, "editable": true, "required": false}
                    }]'
     
   DEFAULT_REQUESTER_FIELDS_JSON   = '[
                    {
                      "fieldType":"default", 
                      "type": "text",     
                      "label": "Requester",  
                      "display_name": "Requester",  
                      "description": "Enter requester name",      
                      "choices": [],  
                      "setDefault": 0, 
                      "agent": {"required": true}, 
                      "customer": {"visible": true, "editable": true, "required": true}
                    },
                     
                    {
                      "fieldType":"default", 
                      "type": "text",      
                      "label": "Subject",   
                      "display_name": "Subject",    
                      "description": "Request subject",           
                      "choices": [], 
                      "setDefault": 0, 
                      "agent": {"required": true}, 
                      "customer": {"visible": true, "editable": true, "required": true}
                    },
                     
                    {
                      "fieldType":"default", 
                      "type": "paragraph", 
                      "label": "Description", 
                      "display_name": "Description",  
                      "description": "",                          
                      "choices": [], 
                      "setDefault": 0, 
                      "agent": {"required": false}, 
                      "customer": {"visible": true, "editable": true, "required": false}
                    }]'
   
  DEFAULT_FIELDS_BY_KEY = Hash['field', DEFAULT_FIELDS_JSON]
      
  CHARACTER_FIELDS = (1..30).collect { |n| "ffs_#{"%02d" % n}" }
  NUMBER_FIELDS = (1..10).collect { |n| "ff_int#{"%02d" % n}" }
  DATE_FIELDS = (1..10).collect { |n| "ff_date#{"%02d" % n}" }
  CHECKBOX_FIELDS = (1..10).collect { |n| "ff_boolean#{"%02d" % n}" }
  TEXT_FIELDS = (1..10).collect { |n| "ff_text#{"%02d" % n}" }
   
end

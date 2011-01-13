class Helpdesk::FormCustomizer < ActiveRecord::Base
  
   set_table_name "helpdesk_form_customizers"
   
   belongs_to :account
   
   DEFAULT_FIELDS_JSON ='[{"fieldType":"default", "type": "text", "label": "Requester", "description": "Enter requester name","choices": [], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}, {"fieldType":"default", "type": "text", "label": "Subject", "description": "Request subject", "choices": [], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}, {"fieldType":"default", "type": "dropdown", "label": "Source", "description": "Source of the request", "choices": [{"value": "Staff initiated", "tags": []}, {"value": "E-mail", "tags": []}], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}, {"fieldType":"default", "type": "dropdown", "label": "Status", "description": "Status of the request", "choices": [{"value": "Open", "tags": []}, {"value": "Closed", "tags": []}], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}, {"fieldType":"default", "type": "dropdown", "label": "Priority", "description": "", "choices": [{"value": "Low", "tags": []}, {"value": "High", "tags": []}], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}, {"fieldType":"default", "type": "dropdown", "label": "Assigned to", "description": "", "choices": [{"value": "Not Assigned", "tags": []}], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}, {"fieldType":"default", "type": "paragraph", "label": "Description", "description": "", "choices": [], "setDefault": 0, "agent": {"required": true}, "customer": {"visible": true, "editable": false, "required": true}}]'
   
   DEFAULT_FIELDS_BY_KEY = Hash['field',DEFAULT_FIELDS_JSON]
   
   
   CHARACTER_FIELDS = Array['ffs_01','ffs_02','ffs_03','ffs_04','ffs_05','ffs_06','ffs_07','ffs_08','ffs_09','ffs_10','ffs_11','ffs_12','ffs_13','ffs_14','ffs_15','ffs_16','ffs_17','ffs_18','ffs_19','ffs_20','ffs_21','ffs_22','ffs_23','ffs_24','ffs_25','ffs_26','ffs_27','ffs_28','ffs_29','ffs_30']
   
   NUMBER_FIELDS = Array['ff_int01','ff_int02','ff_int03','ff_int04','ff_int05','ff_int06','ff_int07','ff_int08','ff_int09','ff_int10']
   
   DATE_FIELDS = Array['ff_date01','ff_date02','ff_date03','ff_date04','ff_date05','ff_date06','ff_date07','ff_date08','ff_date09','ff_date10']
   
   
end

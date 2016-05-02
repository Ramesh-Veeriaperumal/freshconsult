"use strict";

//Following code is used in Zapier.com and not in helpkit . 
//This is a backup of the version hosted on Zapier.com
//-- Hrishikesh 

var Zap = {
    new_ticket_poller_trigger_post_poll: function(bundle) {
        var responseObj = JSON.parse(bundle.response.content);
        if (responseObj.require_login) {
            throw new ErrorException('Your login credentials did not work!');
        }
        return responseObj;
    },
    
    /* Priority in the API is an integer . It is not user Friendly 
    so writing this hack to make it a String for user to use String in Zap and 
    convert to integer when making a call to the API. 
    */
    create_ticket_action_pre_write: function(bundle) {
        var priority=3; // Default to medium 
        
        var data = JSON.parse(bundle.request.data);
        if( data.helpdesk_ticket && data.helpdesk_ticket.priority ){ 
            // If priority was provided change it from String to integer for the API
            priority = data.helpdesk_ticket.priority; 
            if(priority.toUpperCase() == "LOW" ) 
                priority = 4; 
            else if(priority.toUpperCase() == "MEDIUM")
                priority = 3;
            else if(priority.toUpperCase() == "HIGH" ) 
                priority = 2; 
            else if(priority.toUpperCase() == "URGENT")
                priority = 1; 
        }
        data.helpdesk_ticket.priority = priority;
        bundle.request.data = JSON.stringify(data);
        return bundle.request;
    }   , 
    add_notes_to_ticket_action_pre_write: function(bundle) {
        // hard code source to 2 to indicate it is a add note. 
        // API documentation recommends this .. but it works even without this .. 
        
        var data = JSON.parse(bundle.request.data);
        data.helpdesk_note.source = 2 ;
        bundle.request.data = JSON.stringify(data);
        return bundle.request;
    }, 
    get_forums_for_category_trigger_post_poll : function(bundle) {
        // This function is needed because our API doesnt return an array 
        // This function extracts the array from the API response . 
        var output = [];
        try {
            var responseObj = JSON.parse(bundle.response.content);
            output = responseObj.forum_category.forums;
        } 
        catch(e){
            output= []; // lets not break it :)
        }
        return output;
    }, 
    create_forum_topic_action_pre_write: function(bundle) {
        var data = JSON.parse(bundle.request.data);
        if( data.topic.sticky && data.topic.sticky.toString().toUpperCase() == "YES")
            data.topic.sticky = 1;
        else 
            data.topic.sticky = 0;
        if( data.topic.locked && data.topic.sticky.toString().toUpperCase() == "YES")
            data.topic.locked = 1;
        else 
            data.topic.locked = 0;
        data.topic.forum_id = data.forum_id; 
        
        delete data.forum_id;
        
        bundle.request.data = JSON.stringify(data);
        return bundle.request;
    }, 
    getUtils : function(){
        var field_type_map= []; 
        field_type_map["custom_paragraph"] = "text";
        field_type_map["custom_text"] = "unicode";
        field_type_map["custom_number"] = "int";
        field_type_map["custom_checkbox"] = "bool";
        field_type_map["custom_dropdown"] = "unicode";
      
        var utils = {};
      
        utils.translate_field_type = function(fd_field_type){
            var  zap_field_type = "unknown" ;
            if(fd_field_type.search("custom") != -1 )
                zap_field_type = "unicode" ;
            if( field_type_map[fd_field_type])
                zap_field_type = field_type_map[fd_field_type]; 
                
            return zap_field_type;
        };
        
        utils.get_custom_field_label = function(field){
            if(field.visible_in_portal)
                return field.label_in_portal;
            else 
                return field.label;
        };
        
        utils.get_field_key = function(field_name, field_type, zap_type){
            if(field_type.search("custom") != -1){
                if( zap_type == "trigger"){
                    return field_name.replace(/_[0-9]+$/ , "");
                }
                else{
                    return "helpdesk_ticket__custom_field__" + field_name;
                }
            }
            else{
                if( zap_type == "trigger"){
                    return field_name;
                }
                else{
                    return "helpdesk_ticket__" + field_name;
                }
            }
        };
        
        return utils;  
    },
    new_ticket_trigger_post_custom_trigger_fields:function(bundle){
        console.log("Called processing");
        return this.process_custom_fields(bundle, "trigger");
    },
    ticket_updated_trigger_post_custom_trigger_fields:function(bundle){
        console.log("Called processing");
        return this.process_custom_fields(bundle, "trigger");
    },
    create_ticket_action_post_custom_action_fields:function(bundle){
        console.log("Called custom fields processing");
        return this.process_custom_fields(bundle, "action");
    },
    process_custom_fields: function(bundle, zap_type) {
        var utils = this.getUtils();
        
        var customfields = [];
        var customfields_input = JSON.parse(bundle.response.content);
        
        if(customfields_input.access_denied) {
            throw new HaltedException("Access is denied. Please check your authentication details");
        }
        
        customfields = _.map(customfields_input, function(cField){
            cField = cField.ticket_field;
            
            var fieldType = cField.field_type;
            var choices = null;
            if (fieldType == "custom_dropdown"){
                choices = [];
                cField.choices.forEach(function(val){
                    choices.push(val[0]);
                });
            }
            return {
                type : utils.translate_field_type(fieldType),
                key: utils.get_field_key(cField.name, fieldType, zap_type),
                label: utils.get_custom_field_label(cField),
                help_text: cField.description,
                required: false,
                choices : choices
            };
        });
        
        customfields = _.filter(customfields , function(field){
            return field.type != "unknown";
        });
        return customfields;
    }, 
    get_event_data : function(event_name, trigger_fields) {
        console.log("event_name " + event_name);
        var name = "", value = "";
        if ( event_name == "new_ticket" ) {
            name = "ticket_action" ; 
            value = "create";
        }
        if ( event_name == "update_ticket" ) {
            name = "ticket_action" ; 
            value = "update";
        }
        if ( event_name == "new_user" ) {
            name = "user_action" ; 
            value = "create";
        }
        if ( event_name == "update_user" ) {
            name = "user_action" ; 
            value = "update";
        }
        if( event_name == "customer_feedback" ) { 
            name = "customer_feedback" ; 
            value = "--";
        }    
        if( event_name == "ticket_note_added" ) {
            name = "note_action" ; 
            value = "create";
        }
        return [ {"name": name ,"value": value} ]; 
    },
    get_subscription_name : function(bundle){
        var zap_name = "Freshdesk Zapier Zap";
        
        try { 
            zap_name = bundle.zap.action.service.name + " -> " + bundle.zap.name; 
        } 
        catch ( e) { 
            zap_name = bundle.zap.name;
        }
        return zap_name;
    },
    pre_subscribe: function(bundle) {
        bundle.request.url="https://" + bundle.auth_fields.domain_name + ".freshdesk.com/webhooks/subscription.json";
       // bundle.request.url="http://zapiertest.ngrok.com/webhooks/subscription.json";

        bundle.request.method = "POST";
        
        var request_data = {
            "url":bundle.target_url,
            "name":bundle.zap.link,
            "description": this.get_subscription_name(bundle),
            "event_data": this.get_event_data(bundle.event, bundle.trigger_fields)
            //,
            //"performer_data":{"type":"3"} 
        };
       
        //var fields = this.get_fields_for_trigger(bundle.event, bundle.trigger_fields);
        //if( fields ) 
        //    request_data.fields = fields;
        bundle.request.data = JSON.stringify(request_data);
        return bundle.request;
    },
    post_subscribe: function(bundle) {
        var subscribe_data = JSON.parse(bundle.response.content);
        subscribe_data.link=bundle.link;
        return subscribe_data; 
    }, 
    pre_unsubscribe: function(bundle) {
        bundle.request.url="https://" + bundle.auth_fields.domain_name + ".freshdesk.com/webhooks/subscription/";
       // bundle.request.url="http://zapiertest.ngrok.com/webhooks/subscription/";
        bundle.request.url=bundle.request.url + bundle.subscribe_data.id + ".json";
        bundle.request.method = "DELETE";
        bundle.request.data = JSON.stringify({
            "name":bundle.zap.link
        });
        return bundle.request;
    }, 
    new_ticket_trigger_catch_hook: function(bundle){
        return this.get_ticket_data(bundle);
    },
    new_user_trigger_catch_hook: function(bundle){
        return this.get_user_data(bundle);
    },
    update_user_trigger_catch_hook: function(bundle){
        return this.get_user_data(bundle);
    },
    ticket_updated_trigger_catch_hook: function(bundle){
        return this.get_ticket_data(bundle);
    },
    ticket_note_added_trigger_catch_hook:function(bundle){
        var note_data  = this.get_ticket_data(bundle);
        var note_conversion_data = {
            "note_private" : function( key, value ) { 
                key = "private",
                value = value ? "Yes" : "No";
                return[key,value];
            }
        };
        note_data = this.beautify(note_data , "note_", note_conversion_data );
        return note_data;
    },
    get_fields_for_trigger: function(event_name, trigger_fields){
        var fields = "ticket"; 
        if (  event_name == "ticket_note_added" ) { 
            fields = "notes" ;
        }
        if (  event_name == "new_user" ) { 
            fields = "user" ;
        }
        if (  event_name == "update_user" ) { 
            fields = "user" ;
        }
        return fields;
    }, 
    get_ticket_data: function(bundle){
        var data = JSON.parse(bundle.request.content);
        return this.beautify(data.freshdesk_webhook, 'ticket_');
    },
    get_user_data: function(bundle){
        var data = JSON.parse(bundle.request.content);
        return this.beautify(data.freshdesk_webhook, 'user_');
    },
    beautify:function(input, name_str, conversion_data){
        var output = {};
        var replace_str = '';
        for(var attr in input){
            var oattr = attr;
            var value = input[attr];
            if( attr.search(name_str) ===  0 &&  attr.search("_id") ===  -1) {
                oattr = attr.replace(name_str, replace_str);
            }
            if(conversion_data && conversion_data[attr] ) {
                var value_array = conversion_data[attr](attr , input[attr]);
                oattr = value_array[0];
                value = value_array[1];
            }
            output[oattr] = value;
        }
        return output;
    }
};
var Zap = {
    
    /* Priority in the API is an integer . It is not user Friendly 
    so writing this hack to make it a String for user to use String in Zap and 
    convert to integer when making a call to the API. -- Hrishikesh
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
        // This will be a sample to show hard code things for the API - Hrishikesh 
        
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
        
        return utils;  
    },
    create_ticket_action_post_custom_action_fields: function(bundle) {
        var utils = this.getUtils();
        
        var customfields = [];
        
        var inputXml = $.parseXML(bundle.response.content);
        var ticketFieldsSelector = 'helpdesk-ticket-field';
        var xml = $(inputXml).find(ticketFieldsSelector);
        
       
        customfields = _.map(xml, function(element){
            var $element = $(element);
            var fieldType = $element.find('field-type').text();
            var choices = null;
            if (fieldType == "custom_dropdown"){
                choices = [];
                $element.find("choices option value").each(function(){
                    choices.push($(this).text());
                });
            }
            return {
                type : utils.translate_field_type(fieldType),
                key: "helpdesk_ticket__custom_field__" + $element.find('name').text(),
                label: $element.find('label-in-portal').text(),
                help_text: $element.find('description').text(),
                required: ( $element.find('required-in-portal').text() === "true" ), 
                choices : choices
            };
        });
        
        customfields = _.filter(customfields , function(field){
            return field.type != "unknown";
        });
        
        return customfields;
    }, 
    get_event_data : function(event_name, trigger_data) {
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
        if( event_name == "customer_feedback" ) { 
            name = "customer_feedback" ; 
            value = "--";
        }    
        if( event_name == "ticket_note_added" ) {
            name = "note_type" ; 
            if ( trigger_data.ticket_note_type && trigger_data.ticket_note_type == "public" ) 
                value = "public";
            else if ( trigger_data.ticket_note_type && trigger_data.ticket_note_type == "private" ) 
                value = "private";
            else 
                value = "--";
        }
        return [ {"name": name ,"value": value} ]; 
    },
    pre_subscribe: function(bundle) {
        bundle.request.url="http://" + bundle.auth_fields.domain_name + ".freshdesk.com/admin/observer_rules/subscribe.json";
        bundle.request.url="http://zapiertest.ngrok.com/admin/observer_rules/subscribe.json";

        bundle.request.method = "POST";
        
        var request_data = {
            "url":bundle.target_url,
            "name":bundle.zap.link,
            "description": bundle.zap.name,
            "event_data": this.get_event_data(bundle.event, bundle.trigger_data),
            "performer_data":{"type":"3"}
        };
       
        var fields = this.get_fields_for_trigger(bundle.event, bundle.trigger_data);
        if( fields ) 
            request_data.fields = fields;
        bundle.request.data = JSON.stringify(request_data);
        return bundle.request;
    }, 
    pre_unsubscribe: function(bundle) {
        bundle.request.url="http://" + bundle.auth_fields.domain_name + ".freshdesk.com/admin/observer_rules/unsubscribe.json";
        bundle.request.url="http://zapiertest.ngrok.com/admin/observer_rules/unsubscribe.json";
        bundle.request.method = "DELETE";
        bundle.request.data = JSON.stringify({
            "name":bundle.zap.link
        });
        return bundle.request;
    }, 
    new_ticket_trigger_catch_hook: function(bundle){
        var data = JSON.parse(bundle.request.content);
        return data.freshdesk_webhook;
    },
    ticket_updated_trigger_catch_hook: function(bundle){
        var data = JSON.parse(bundle.request.content);
        return data.freshdesk_webhook;
    },
    ticket_note_added_trigger_catch_hook:function(bundle){
        var ticket_note_type = bundle.trigger_fields.ticket_note_type ; 
        var data = JSON.parse(bundle.request.content);
        return data.freshdesk_webhook;
    },
    get_fields_for_trigger: function(event_name, trigger_data){
        var fields = "ticket"; 
        if (  event_name == "ticket_note_added" ) { 
            fields = "notes" ;
        }
        if (  event_name == "new_user" ) { 
            fields = "user" ;
        }
        return fields;
    }
};
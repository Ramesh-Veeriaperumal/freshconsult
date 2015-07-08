var get_due_by_value = function (time) {
    switch (true) {
    case time < 0:
        return '1';
    case time < 8 && time > 0:
        return '4';
    case time < 24 && time > 8:
        return '2';
    case time < 48 && time > 48:
        return '3';
    }
};

var addToSet = function(set,value){
  if(!set[value]){
    set[value] = true;
  }
};

var ignoreTicketChange = function(ticket_id){
  var quick_action_ticket = jQuery("#all-views").data("quickAction")
  if(quick_action_ticket && quick_action_ticket === ticket_id) {
    jQuery("#all-views").data("quickAction", 0);
    return true
  }
  return false
}

var show_refresh_alert = function (message, div_to_refresh, updated_tickets) {
    if(ignoreTicketChange(message.display_id)){
      return false
    }
    addToSet(updated_tickets, message.id);
    update_counter(div_to_refresh, Object.keys(updated_tickets).length);
    jQuery("#index_refresh_alert").slideDown(100);
    flash_ticket(message.display_id);
};

var update_counter = function (id, count) {
    var element = jQuery(id);
    element.text((count > 1) ? element.data("textOther") : element.data("textOne"))
        .attr("data-count", count)
        .show();
};

var flash_ticket = function (ticket_id) {
    if (jQuery("[data-ticket=" + ticket_id + "]")) {
        jQuery("[data-ticket=" + ticket_id + "] .status-source").addClass('source-detailed-auto-refresh');
        jQuery("[data-ticket=" + ticket_id + "] .status-source").attr("title", '');
        // updated_tickets.push("[data-ticket=" + ticket_id + "] td");
    }
};

var refreshCallBack = function (message, hashed_params, current_userid,updated_tickets,new_tickets) {
    var filter_options = JSON.parse(jQuery("input[name=data_hash]").val());
    var count = 0;
    var tickets_list;
    var div_name;

    if (message.type === 'create'){
      tickets_list = new_tickets;
      div_name = "#new_ticket_message"
    }
    else {
      tickets_list = updated_tickets;
      div_name = "#update_message"
    }

    if (jQuery("[data-ticket=" + message.display_id + "]").length != 0) {
          show_refresh_alert(message, div_name, tickets_list);
    } else if (filter_options.length != 0) {
        // console.log('The filter_options is not 0', filter_options);
        for (var i = 0; i < filter_options.length; i++) {
            var filter_values = filter_options[i].value.split(',');
            
            if (filter_options[i].condition == "due_by" &&
              filter_values.indexOf(get_due_by_value((message['due_by']*1000 - Date.now())/3600000)) >= 0){
              count++;
            }
            else if (filter_options[i].condition == "created_at"){
              var created_at = new Date(message['created_at']*1000);
              var created_at_filter = filter_options[i].value;
              if (!isNaN(created_at_filter) &&
                (((Date.now() - created_at) / 60000) < ((filter_options[i].value) - ''))) {
                  count++;
              } else if (created_at_filter == "yesterday" &&
                (created_at < Date.today()) && 
                (created_at > Date.today().add({ days: -1 }))) {
                  count++;
              } else if (created_at_filter.split("-").length == 2 &&
                  created_at > Date.parse(date_arr[0]) &&
                  created_at < Date.parse(date_arr[1])) {
                    count++;
              } else if (created_at > auto_refresh_ticketFilterDateoptions[created_at_filter]) {
                count++;
              }
            }
            else if ((filter_options[i].ff_name == "default")) {
              if (filter_options[i].condition == "responder_id") {
                if (filter_values.indexOf('0') >= 0) {
                    filter_values[filter_values.indexOf('0')] = current_userid;
                }
              }
              if (filter_options[i].condition == "group_id") {
                if (filter_values.indexOf('0') >= 0) {
                    filter_values[filter_values.indexOf('0')] = undefined;
                    filter_values = filter_values.concat(hashed_params['groups'].map(function(val){ return val+'';}));
                }
              }

              if(filter_options[i].condition == "helpdesk_tags.name"){
                for(var t = 0; t < message["tag_names"].length; t++){
                  if(filter_values.indexOf(message["tag_names"][t]) >= 0){
                    count++;
                    break;
                  }
                } 
              }

              var message_val = (message[filter_options[i].condition]) ? 
                message[filter_options[i].condition]
                : "-1";
              if (presentInList(filter_values, message_val) >= 0) {
                count++;
              } 
            }
            else if (
              (filter_options[i].ff_name != "default") &&
              Object.keys(message['custom_fields']).length != 0 &&
              presentInList(filter_values, message['custom_fields'][filter_options[i].ff_name]) >= 0) {
                count++;
            }
        };
        if (count == filter_options.length) {
            show_refresh_alert(message, div_name, tickets_list);
        }
    } else {
        show_refresh_alert(message, div_name, tickets_list);
    }
};

var presentInList = function(filter_values, msg_val){
  var msg_type = typeof(msg_val);
  if (msg_val){
    if (msg_type == "string" || msg_type == "number"){
      return filter_values.indexOf(msg_val.toString());
    }else{
      for (var i=0; i < msg_val.length; i++){
        if (filter_values.indexOf(msg_val[i].toString()) >= 0){
            return 1;
        }
      }
    }
  }
  return -1;
}

window.autoRefresh = function(server, hashed_params, current_username, current_userid){
  var node_socket = agentio.connect(server, {'force new connection':true, 'sync disconnect on unload':true});
  window.node_socket = node_socket;
  jQuery("#index_refresh_alert").data("updated", {});
  jQuery("#index_refresh_alert").data("created", {});

  node_socket.on('connect', function(){
    console.log('I have ticket_status.connected');
  });
    
  node_socket.on('connection_complete',function(){
    ticket_status.connected = true;
  });

  node_socket.on('message',function(data){
    var refresh_alert = jQuery("#index_refresh_alert");
    var updated_tickets = refresh_alert.data("updated");
    var new_tickets = refresh_alert.data("created");
    refreshCallBack(data, hashed_params, current_userid, updated_tickets, new_tickets);
    refresh_alert.data("updated", updated_tickets);
    refresh_alert.data("created", new_tickets);
  });

  node_socket.on('auto_refresh',function(data){
    if(data.action === 'connect'){
      node_socket.emit('auto_refresh_connect', hashed_params);
    }
  });

  node_socket.on('disconnect', function() {  
    ticket_status.connected = false;
  });

};

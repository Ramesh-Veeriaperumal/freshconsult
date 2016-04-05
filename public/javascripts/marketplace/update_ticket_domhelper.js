//updating ticket details when ticket properties and custom fields are updated
$(function(){

  function updateCustomFields(data, key){
    var customField = JSON.stringify(key),
        mainKey = customField.slice(31, customField.length-2),
        ticketObj = domHelper.getTicketInfo();

    if(ticketObj.helpdesk_ticket.custom_field.hasOwnProperty(mainKey)){
      ticketObj.helpdesk_ticket.custom_field[mainKey] = data[key].value;
    }
  }

  jQuery(document).on('ticket_fields_updated', function(ev, data) {
    var ticketObj = domHelper.getTicketInfo();
    for(var key in data) {
      switch(key){
        case "helpdesk_ticket[priority]":
          ticketObj.helpdesk_ticket.priority = data[key].value;
          ticketObj.helpdesk_ticket.priority_name = data[key].name;
          break;
        case "helpdesk_ticket[status]":
          ticketObj.helpdesk_ticket.status = data[key].value;
          ticketObj.helpdesk_ticket.status_name = data[key].name;
          break;
        case "helpdesk_ticket[source]":
          ticketObj.helpdesk_ticket.source = data[key].value;
          ticketObj.helpdesk_ticket.source_name = data[key].name;
          break;
        case "helpdesk_ticket[ticket_type]":
          ticketObj.helpdesk_ticket.ticket_type = data[key].value;
          break;
        case "helpdesk_ticket[group_id]":
          ticketObj.helpdesk_ticket.group_id = data[key].value;
          break;
        case "helpdesk_ticket[responder_id]":
          ticketObj.helpdesk_ticket.responder_id = data[key].value;
          ticketObj.helpdesk_ticket.responder_name = data[key].name;
          break;
        case "helpdesk[tags]":
          ticketObj.helpdesk_ticket.tag_list = data[key].value;
          break;
        default:
          updateCustomFields(data, key);
      }
    }
  });
})();

//updating cached ticket details when note, reply added/updated throeugh custome events

$(function(){

  function getNewNoteData(receivedNote){
    var data = {}
    data = receivedNote;
    return data;
  }

  function getUpdatedNotesForDH(receivedNote){
    var newNote = getNewNoteData(receivedNote),
        ticketObj = domHelper.ticket.getTicketInfo(),
        notesCount = ticketObj.helpdesk_ticket.notes.length;

    for(var i = 0 ; i < notesCount; i++){
      if(newNote.note.id == ticketObj.helpdesk_ticket.notes[i].note.id){
        ticketObj.helpdesk_ticket.notes[i] = newNote;
      }
    }
    return ticketObj;
  }

  function buildCustomFields(data, key){
    var customField = JSON.stringify(key),
        mainKey = customField.slice(31, customField.length-2),
        ticketObj = domHelper.ticket.getTicketInfo();
        
    if(ticketObj.helpdesk_ticket.custom_field.hasOwnProperty(mainKey)){
      ticketObj.helpdesk_ticket.custom_field[mainKey] = data[key].value;
    }
  }

  jQuery(document).on('note_created', function(ev, data) {
    var newNote = getNewNoteData(data),
        ticketObj = domHelper.ticket.getTicketInfo(),
        newIndex = ticketObj.helpdesk_ticket.notes.length;
  
    ticketObj.helpdesk_ticket.notes[newIndex] = newNote;
  });

  jQuery(document).on('note_updated', function(ev, data) { 
    var ticketObj = getUpdatedNotesForDH(data);
  });

  jQuery(document).on('note_deleted', function(ev, data) { 
    var ticketObj = getUpdatedNotesForDH(data);
  });
  
  jQuery(document).on('ticket_fields_updated', function(ev, data) { 
    console.log(data);
    var ticketObj = domHelper.ticket.getTicketInfo();
    for(var key in data) {
      switch(true){
        case key == "helpdesk_ticket[priority]":
          console.log("priority case");
          ticketObj.helpdesk_ticket.priority = data[key].value;
          ticketObj.helpdesk_ticket.priority_name = data[key].name;
          break;
        case key == "helpdesk_ticket[status]":
          console.log("status case");
          ticketObj.helpdesk_ticket.status = data[key].value;
          ticketObj.helpdesk_ticket.status_name = data[key].name;
          break;
        case key == "helpdesk_ticket[source]":
          console.log("source case");
          ticketObj.helpdesk_ticket.source = data[key].value;
          ticketObj.helpdesk_ticket.source_name = data[key].name;
          break;
        case key == "helpdesk_ticket[ticket_type]":
          console.log("ticket_type case");
          ticketObj.helpdesk_ticket.ticket_type = data[key].value;
          break;
        case key == "helpdesk_ticket[group_id]":
          console.log("group_id case");
          ticketObj.helpdesk_ticket.group_id = data[key].value;
          break;
        case key == "helpdesk_ticket[responder_id]":
          console.log("responder_id case");
          ticketObj.helpdesk_ticket.responder_id = data[key].value;
          ticketObj.helpdesk_ticket.responder_name = data[key].name;
          break;
        case key == "helpdesk[tags]":
          ticketObj.helpdesk_ticket.tags = [];
          var allTags = data[key].value.split(',');
          for(var j=0; j< allTags.length; j++){
            ticketObj.helpdesk_ticket.tags.push({name: allTags[j]});
          }
          break;
        default:
          buildCustomFields(data, key);
      }
    }
    
  });


})();
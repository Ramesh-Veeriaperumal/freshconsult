var domHelper = domHelper || {};

(function(dh){

  init:(function (){
    //FOR DATA MANIPULATION ONCE CORE TEAM COMES UP WITH UPDATED OBJ
  })();

  // Helper Object Methods (API)
  if(page_type === "ticket"){
    // get current ticket data in json format
    dh.getTicketInfo = function(opt){
      return tktDetailDom.getTicketInfo(opt);
    }

    // open reply box
    dh.openReply = function(reply_text){
     tktDetailDom.openReply(reply_text);
    }

    dh.openNote = function(note_text){
      tktDetailDom.openNote(note_text);
    }

    dh.expandConversations = function(){
      tktDetailDom.expandConversations();
    }

    // hide ticket delete
    dh.hideTicketDelete = function(){
      tktDetailDom.hideTicketDelete();
    }

    // show ticket delete
    dh.showTicketDelete = function(){
      tktDetailDom.showTicketDelete();
    }

    // hide attachments
    dh.hideAttachments = function(){
      tktDetailDom.hideAttachments();
    }

    // show attachments
    dh.showAttachments = function(){
      tktDetailDom.showAttachments();
    }

    //trigger click on some element
    dh.triggerClick = function(element){
      tktDetailDom.triggerClick(element);
    }

    //trigger reload on some element
    dh.triggerReload = function(element){
      tktDetailDom.triggerReload(element);
    }

    //add an option to 'more' dropdown
    dh.addExtraOption = function(anchor_tag){
      tktDetailDom.addExtraOption(anchor_tag);
    }

    //add custom button in ticket menu
    dh.addCustomButton = function(anchor_tag){
      tktDetailDom.addCustomButton(anchor_tag);
    }

    //add custom button in ticket menu
    dh.appendToSidebar = function(markup){
      tktDetailDom.appendToSidebar(markup);
    }

  }

  if(page_type === "contact"){
    // get current contact data in json format
    dh.getContactInfo = function(opt){
      return contactDom.getContactInfo(opt);
    }

    //convert contact to agent
    dh.convertToAgent = function(agent_type){
      contactDom.convertToAgent(agent_type);
    }

    //add custom button in ticket menu
    dh.setBackgroundInfo = function(text){
      contactDom.setBackgroundInfo(text);
    }

    //add custom button in ticket menu
    dh.appendToContactSidebar = function(markup){
      contactDom.appendToContactSidebar(markup);
    }
    
  }
})(domHelper);


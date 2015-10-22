/*
  Listener to dom_helper.js messages.
  Load this js as a part of top window (not within an iframe/other window).
*/

$(function(){

  window.addEventListener("message", processRequest, false);

  // supported for ticket and contact page
  // (called as per current window)
  function GetPageInfo(e){
    var message = {};
    message.id = 'helpkit-response-data';
    message.response = dom_helper_data;
    // remove from global namespace
    dom_helper_data = null;
    e.source.postMessage(message,e.origin);
  }

  function processRequest(event){
    // if (event.origin !== "http://example.org:8080")
    //   return;
    var todo = event.data.id;
    if (typeof todo === undefined || todo == "helpkit-response-data")
      return;

    // initialize if not defined (just to avoid undefined object)
    if(page_type === "ticket"){ contactDom = {};}
    if(page_type === "contact"){ tktDetailDom = {};}

    var msg_method_map={
      "open-reply-box" : tktDetailDom.openReplyBox,
      "hide-tkt-delete" : tktDetailDom.hideTicketDelete,
      "show-tkt-delete" : tktDetailDom.showTicketDelete,
      "hide-attachments" : tktDetailDom.showAttachments,
      "trigger-click" : tktDetailDom.triggerClick,
      "trigger-reload": tktDetailDom.triggerReload,
      "add-to-dropdown" : tktDetailDom.addOptionToMoreDropdown,
      "add-custom-button" : tktDetailDom.addCustomButton,
      "append-to-sidebar" : tktDetailDom.appendToSidebar,
      "convert-to-agent" : contactDom.convertToAgent,
      "set-background-info" : contactDom.setBackgroundInfo,
      "append-to-contact-sidebar" : contactDom.appendToContactSidebar,
      "request-page-details" : GetPageInfo
    }

    if(typeof msg_method_map[todo] == 'function'){
      todo == "request-page-details" ? msg_method_map[todo](event) : msg_method_map[todo](event.data.options);
    }
  }
})();

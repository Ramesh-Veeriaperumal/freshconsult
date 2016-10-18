/*
The helpURLs for each of the APIs needs to be updated
in the dhValidator.helpURL once help documentation is available
*/
var domHelperValidator = domHelperValidator || {};

(function(dhValidator){

  dhValidator.ticketHelpDetails = {
    getTicketInfo: { signature: "", description: "Returns the ticket information object", helpURL: "getTicketInfo" },
    getContactInfo: { signature: "", description: "Returns the contact information of the requester", helpURL: "getContactInfo" },
    getCustomField: { signature: "", description: "Returns the custom fields of the ticket", helpURL: "getCustomField" },
    expandConversations: { signature: "", description: "Expands all the collapsed conversations", helpURL: "" },
    hideAttachments: { signature: "", description: "Hides the attachments in the conversation", helpURL: "" },
    showAttachments: { signature: "", description: "Displays the attachments in the conversation if hidden", helpURL: "" },
    hideTicketDelete: { signature: "", description: "Hides the ticket delete option from the menu", helpURL: "" },
    showTicketDelete: { signature: "", description: "Displays the ticket delete option in the menu", helpURL: "" },
    openReply: { signature: "text", description: "Opens reply box and adds the text", helpURL: "" },
    openNote: { signature: "text", description: "Opens note box and adds the text", helpURL: "" },
    onReplyClick: { signature: "callbackFunction", description: "Executed when Reply is clicked", helpURL: "" },
    onForwardClick: { signature: "callbackFunction", description: "Executed when Forward is clicked", helpURL: "" },
    onAddNoteClick: { signature: "callbackFunction", description: "Executed when Add note is clicked", helpURL: "" },
    onSubmitClick: { signature: "callbackFunction, ['reply','forward','note']", description: "Executed when reply/forward/note is submitted based on the parameter", helpURL: "" },
    onTicketCloseClick: { signature: "callbackFunction", description: "Executed when a ticket is closed", helpURL: "" },
    onPrevTicketClick: { signature: "callbackFunction", description: "Executed when previous ticket option is clicked", helpURL: "" },
    onNextTicketClick: { signature: "callbackFunction", description: "Executed when next ticket option is clicked", helpURL: "" },
    onPriorityChanged: { signature: "callbackFunction", description: "Executed when priority of a ticket is changed", helpURL: "" },
    onStatusChanged: { signature: "callbackFunction", description: "Executed when status of a ticket is changed", helpURL: "" },
    onSourceChanged: { signature: "callbackFunction", description: "Executed when source of a ticket is changed", helpURL: "" },
    onGroupChanged: { signature: "callbackFunction", description: "Executed when the group assigned to a ticket is changed", helpURL: "" },
    onAgentChanged: { signature: "callbackFunction", description: "Executed when agent assigned to a ticket is changed", helpURL: "" },
    onTypeChanged: { signature: "callbackFunction", description: "Executed when type of the ticket is changed", helpURL: "" },
    onTicketPropertiesUpdated: { signature: "callbackFunction", description: "Executed when ticket properties are updated", helpURL: "" },
    showConfirm: { signature: "evt, title, messageToDisplay, ok_label, cancel_label, ok_callback, cancel_callback", description: "Shows the Confirm dialog box. ok_callback / cancel_callback is executed based on the user action on ok / cancel option", helpURL: "" },
    showModal: { signature: "evt, title, messageToDisplay, ok_label, ok_callback", description: "Shows the Modal dialog box. ok_callback is executed when the user clicks on the ok option", helpURL: "" },
    triggerClick: { signature: "element", description: "Triggers click of the given element", helpURL: "" },
    triggerReload: { signature: "element", description: "Triggers reload of the given element", helpURL: "" }
  };
  dhValidator.contactHelpDetails = {
    getContactInfo: { signature: "", description: "Returns the contact information object", helpURL: "getTicketInfo" },
    getCustomField: { signature: "", description: "Returns the custom fields of user", helpURL: "getCustomField" },
    convertToAgent: { signature: "agent_type", description: "Converts the contact to a fulltime / occasional agent", helpURL: "convertToAgent" }
  };

  dhValidator.ticketHelpLink = "https://freshdesk.com/api#ticket";
  dhValidator.contactHelpLink = "https://freshdesk.com/api#contact";
  dhValidator.helpURLPrefix = "https://freshdesk.com/api#";
  dhValidator.displayHelpMessage = "More details can be found at %s";

  //constants for displaying error log
  dhValidator.invalidParams = "invalidParams";
  dhValidator.missingParams = "missingParams";
  dhValidator.invalidElement = "invalidElement";
  dhValidator.callBkFn = "callBkFn";

  //error message to be displayed in console log
  dhValidator.errorMessageMap = {
    invalidParams: "Invalid parameters for ",
    missingParams: "Missing parameters for ",
    invalidElement: "Invalid Element %s passed in %s",
    callBkFn: "Callback function not defined for ",
    invalidArgumentValue: "Invalid argument %s passed for %s",
    learnMore: "Learn more at %s"
  };

  init:(function (){
  })();

  dhValidator.checkParamsForError = function(arguments, apiName, paramsList){
    var errorMessage = "";
    var params = paramsList.split(",");
    for(var i = 0; i < params.length; i++){
      if(!arguments[i]){
        errorMessage = "Undefined argument " + params[i] + " for " + apiName;
        return errorMessage;
      }
    }
  }

  dhValidator.getErrorMessage = function(apiName, errorMsgType){
    if(errorMsgType && this.errorMessageMap[errorMsgType] && apiName){
      return this.errorMessageMap[errorMsgType] + apiName;
    }
  }

})(domHelperValidator);

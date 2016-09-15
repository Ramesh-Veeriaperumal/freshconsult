var domHelper = domHelper || {};

(function(dh){

  init:(function (){
    isCallBack = true;
    helpContent = {};
    helpLink = "";
    //FOR DATA MANIPULATION ONCE CORE TEAM COMES UP WITH UPDATED OBJ
  })();

  // Helper Object Methods (API)
  if(page_type === "ticket"){
    helpLink = domHelperValidator.ticketHelpLink;
    helpContent = domHelperValidator.ticketHelpDetails;

    domHelper.ticket = {  
      // get current ticket data in json format
      getTicketInfo: function(){
        return tktDetailDom.getTicketInfo();
      },

      // get requester user info in json format
      getContactInfo: function() {
        return tktDetailDom.getContactInfo();
      },

      //get custom fields of ticket details
      getCustomField: function() {
        return tktDetailDom.getCustomField();
      },

      // open reply box
      openReply: function(reply_text){
       tktDetailDom.openReply(reply_text);
      },

      openNote: function(note_text){
        tktDetailDom.openNote(note_text);
      },

      expandConversations: function(){
        tktDetailDom.expandConversations();
      },

      // hide ticket delete
      hideTicketDelete: function(){
        tktDetailDom.hideTicketDelete();
      },

      // show ticket delete
      showTicketDelete: function(){
        tktDetailDom.showTicketDelete();
      },

      // hide attachments
      hideAttachments: function(){
        tktDetailDom.hideAttachments();
      },

      // show attachments
      showAttachments: function(){
        tktDetailDom.showAttachments();
      },

      //trigger click on some element
      triggerClick: function(element){
        dh.domHelperCallValidator("triggerClick", element);
      },

      //trigger reload on some element
      triggerReload: function(element){
        dh.domHelperCallValidator("triggerReload", element);
      },

      onReplyClick: function(callback){
        dh.domHelperCallValidator("onReplyClick", callback, isCallBack);
      },

      /** @deprecated  */
      onFwdClick: function(callback) {
        console.warn("onFwdClick API has been deprecated. Please use onForwardClick instead.")
        dh.domHelperCallValidator("onForwardClick", callback, isCallBack);
      },

      onForwardClick: function(callback) {
        dh.domHelperCallValidator("onForwardClick", callback, isCallBack);
      },

      onAddNoteClick: function(callback) {
        dh.domHelperCallValidator("onAddNoteClick", callback, isCallBack);
      },

      onSubmitClick: function(callback, what) {
        if(!callback || (typeof callback) != 'function'){
          dh.displayDomHelperError("onSubmitClick", domHelperValidator.callBkFn);
        }
        else if(!what){
          dh.displayDomHelperError("onSubmitClick", domHelperValidator.missingParams);
        }
        else{
          tktDetailDom.onSubmitClick(callback, what);
        }
      },

      onTicketCloseClick: function(callback) {
        dh.domHelperCallValidator("onTicketCloseClick", callback, isCallBack);
      },

      onPrevTicketClick :function(callback) {
        dh.domHelperCallValidator("onPrevTicketClick", callback, isCallBack);
      },

      onNextTicketClick: function(callback) {
        dh.domHelperCallValidator("onNextTicketClick", callback, isCallBack);
      },

      onPriorityChanged: function(callback) {
        dh.domHelperCallValidator("onPriorityChanged", callback, isCallBack);
      },

      onStatusChanged: function(callback) {
        dh.domHelperCallValidator("onStatusChanged", callback, isCallBack);
      },

      onSourceChanged : function(callback) {
        dh.domHelperCallValidator("onSourceChanged", callback, isCallBack);
      },

      onGroupChanged : function(callback) {
        dh.domHelperCallValidator("onGroupChanged", callback, isCallBack);
      },

      onAgentChanged : function(callback) {
        dh.domHelperCallValidator("onAgentChanged", callback, isCallBack);
      },

      onTypeChanged : function(callback) {
        dh.domHelperCallValidator("onTypeChanged", callback, isCallBack);
      },

      onTicketPropertiesUpdated : function(callback) {
        dh.domHelperCallValidator("onTicketPropertiesUpdated", callback, isCallBack);
      }
    }
  }

  if(page_type === "contact"){
    helpLink = domHelperValidator.contactHelpLink;
    helpContent = domHelperValidator.contactHelpDetails;

    domHelper.contact = {  

      // get current contact data in json format
      getContactInfo : function(){
        return contactDom.getContactInfo();
      },

      //get the custom fields of user
      getCustomField: function(){
        return contactDom.getCustomField();
      },

      //convert contact to agent
      convertToAgent : function(agent_type){
        dh.domHelperCallValidator("convertToAgent", agent_type);
      }
    }
  }

  dh.getAgentEmail = function() {
    return current_user.user.email;
  }

  dh.getDomainName = function() {
    return current_account_full_domain
  }

  dh.showConfirm = function(evt, title, msg, ok_label, cancel_label, success_cb, failure_cb){
    var paramsError = domHelperValidator.checkParamsForError(arguments, "showConfirm", "evt,title,msg,ok_label,cancel_label,success_cb,failure_cb");
    if(paramsError){
      console.error(paramsError);
      console.info(domHelperValidator.errorMessageMap["learnMore"], domHelperValidator.helpURLPrefix + helpContent["showConfirm"]["helpURL"]);
    }
    else if((typeof success_cb) != 'function' || (typeof failure_cb) != 'function'){
      this.displayDomHelperError("showConfirm", callBkFn);
    }
    else{
      tktDetailDom.showConfirm(evt, title, msg, ok_label, cancel_label, success_cb, failure_cb);
    }
  }

  dh.showModal = function(evt, title, msg, ok_label, success_cb){
    var paramsError = domHelperValidator.checkParamsForError(arguments, "showModal", "evt,title,msg,ok_label,success_cb");
    if(paramsError){
      console.error(paramsError);
      console.info(domHelperValidator.errorMessageMap["learnMore"], domHelperValidator.helpURLPrefix + helpContent["showModal"]["helpURL"]);
    }
    else if((typeof success_cb) != 'function'){
      this.displayDomHelperError("showModal", callBkFn);
    }
    else{
      tktDetailDom.showModal(evt, title, msg, ok_label, success_cb);
    }
  }

  dh.help = function(){
    var content = "";
    for(var api in helpContent){
      content += api +"(" + helpContent[api]["signature"] + ")\n\t" + helpContent[api]["description"] + "\n\n";
    }
    console.info(content);
    console.info(domHelperValidator.displayHelpMessage, helpLink);
  }

  dh.domHelperCallValidator = function(apiName, params, isCallBack) {
    if(params){
      if(isCallBack && (typeof params) != 'function'){
        console.error(domHelperValidator.getErrorMessage(apiName, domHelperValidator.callBkFn));
      }
      else{
        switch (page_type) {
          case "ticket":
            tktDetailDom[apiName](params);
            break;
          case "contact":
            contactDom[apiName](params);
            break;
        }
      }
    }
    else{
      if(apiName != 'addCustomButton') {
        console.error(domHelperValidator.getErrorMessage(apiName, domHelperValidator.missingParams));
      }
    }
  }

  dh.displayDomHelperError = function(apiName, errorMsgType) {
    console.error(domHelperValidator.getErrorMessage(apiName, errorMsgType));
  }

})(domHelper);

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

    // get current ticket data in json format
    dh.getTicketInfo = function(){
      return tktDetailDom.getTicketInfo();
    }

    // get requester user info in json format
    dh.getContactInfo = function() {
      return tktDetailDom.getContactInfo();
    }

    //get custom fields of ticket details
    dh.getCustomField = function() {
      return tktDetailDom.getCustomField();
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
      this.domHelperCallValidator("triggerClick", element);
    }

    //trigger reload on some element
    dh.triggerReload = function(element){
      this.domHelperCallValidator("triggerReload", element);
    }

    //add an option to 'more' dropdown
    dh.addExtraOption = function(anchor_tag){
      this.domHelperCallValidator("addExtraOption", anchor_tag);
    }

    //add custom button in ticket menu
    dh.addCustomButton = function(anchor_tag){
      this.domHelperCallValidator("addCustomButton", anchor_tag);
    }

    //add custom button in ticket menu
    dh.appendToSidebar = function(markup){
      this.domHelperCallValidator("appendToSidebar", markup);
    }

    dh.onReplyClick = function(callback){
      this.domHelperCallValidator("onReplyClick", callback, isCallBack);
    }

    dh.onFwdClick = function(callback) {
      this.domHelperCallValidator("onFwdClick", callback, isCallBack);
    }

    dh.onAddNoteClick = function(callback) {
      this.domHelperCallValidator("onAddNoteClick", callback, isCallBack);
    }

    dh.onSubmitClick = function(callback, what) {
      if(!callback || (typeof callback) != 'function'){
        this.displayDomHelperError("onSubmitClick", domHelperValidator.callBkFn);
      }
      else if(!what){
        this.displayDomHelperError("onSubmitClick", domHelperValidator.missingParams);
      }
      else{
        tktDetailDom.onSubmitClick(callback, what);
      }
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

    dh.onTicketCloseClick = function(callback) {
      this.domHelperCallValidator("onTicketCloseClick", callback, isCallBack);
    }

    dh.onPrevTicketClick = function(callback) {
      this.domHelperCallValidator("onPrevTicketClick", callback, isCallBack);
    }

    dh.onNextTicketClick = function(callback) {
      this.domHelperCallValidator("onNextTicketClick", callback, isCallBack);
    }

    dh.onPriorityChanged = function(callback) {
      this.domHelperCallValidator("onPriorityChanged", callback, isCallBack);
    }

    dh.onStatusChanged = function(callback) {
      this.domHelperCallValidator("onStatusChanged", callback, isCallBack);
    }

    dh.onSourceChanged = function(callback) {
      this.domHelperCallValidator("onSourceChanged", callback, isCallBack);
    }

    dh.onGroupChanged = function(callback) {
      this.domHelperCallValidator("onGroupChanged", callback, isCallBack);
    }

    dh.onAgentChanged = function(callback) {
      this.domHelperCallValidator("onAgentChanged", callback, isCallBack);
    }

    dh.onTypeChanged = function(callback) {
      this.domHelperCallValidator("onTypeChanged", callback, isCallBack);
    }

    dh.onTicketPropertiesUpdated = function(callback) {
      this.domHelperCallValidator("onTicketPropertiesUpdated", callback, isCallBack);
    }
  }

  if(page_type === "contact"){
    helpLink = domHelperValidator.contactHelpLink;
    helpContent = domHelperValidator.contactHelpDetails;

    // get current contact data in json format
    dh.getContactInfo = function(){
      return contactDom.getContactInfo();
    }

    //get the custom fields of user
    dh.getCustomField = function(){
      return contactDom.getCustomField();
    }

    //convert contact to agent
    dh.convertToAgent = function(agent_type){
      this.domHelperCallValidator("convertToAgent", agent_type);
    }

    //add custom button in ticket menu
    dh.appendToContactSidebar = function(markup){
      this.domHelperCallValidator("appendToContactSidebar", markup);
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

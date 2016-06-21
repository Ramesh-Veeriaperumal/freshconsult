var ContactDom = Class.create({
  initialize: function() {
    jQuery(window).on("message.extn", this.receiveFAMessage.bindAsEventListener(this));
  },

  // contact page dom related
  getContactInfo: function(opt){
    if(opt){
      var msg_for_extn = {
        dom_helper_data: dom_helper_data,
        type: "FA_FROM_HK"
      }
      window.postMessage(msg_for_extn, "*");
    }
    else{
      return dom_helper_data;
    }
  },
  
  receiveFAMessage: function(event){
    var data = event.originalEvent.data;
    if(page_type == "contact"){
      if(data.type == "FA_DOM_EVENTS") {
        method = data.action;
        this[method](data.txt);
      } 
      else if(data.type == "FA_TO_HK"){
        this.getContactInfo(data.txt);
      }
    }
  },

  getCustomField: function(){
    return dom_helper_data.user.custom_field;
  },

  convertToAgent: function(options){
    var email = domHelper.contact.getContactInfo().user.email;
    if(email != null){
      if(options){
        var id = options;
        var valid = jQuery.inArray(id, ['fulltime','occasional']);
        if(valid == 0){
          jQuery("[data-domhelper-name='convert-agent-fulltime']").trigger("click");
        }
        else if(valid == 1){
          jQuery("[data-domhelper-name='convert-agent-occasional']").trigger("click");
        }
      }
    }
  },

  destroy: function(){
    dom_helper_data = {};
    //need to clear all sorts of data manipulations when navigating away.
  }
});
var contactDom = new ContactDom();
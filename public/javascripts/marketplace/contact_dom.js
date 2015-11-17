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

  convertToAgent: function(options){
    if(options){
      var id = options;
      var valid = jQuery.inArray(id, ['fulltime','occasional']);
      var el = jQuery("ul.dropdown-menu.pull-right");
      if(valid == 0){
        jQuery(el).find("li:first a").trigger("click");
      }
      else if(valid == 1){
       jQuery(el).find("li:last a").trigger("click");
      }
    }
  },

  setBackgroundInfo: function(options){
    if(options){
      jQuery('textarea#user_description').val(options);
      jQuery('input#user_submit').trigger('click');
    }
  },

  appendToContactSidebar: function(options){
    if(options){
      jQuery('div.contact-sidebar-content').append(options);
    }
  },

  destroy: function(){
    dom_helper_data = {};
    //need to clear all sorts of data manipulations when navigating away.
  }
});
var contactDom = new ContactDom();
var contactDom = contactDom || {};

(function(cd){

  // Declare required dom manipulations for contact page.

  // convert to agent
  cd.convertToAgent = function(options){
    if(options.agent_type){
      var id = options.agent_type;
      var valid = jQuery.inArray(id, ['fulltime','occasional']);
      (valid >= 0) && jQuery('a#'+id).trigger('click');
    }
  }

  //set background info
  cd.setBackgroundInfo = function(options){
    if(options.text){
      jQuery('textarea#user_description').val(options.text);
      jQuery('input#user_submit').trigger('click');
    }
  }

  // append to contacts page sidebar
  cd.appendToContactSidebar = function(options){
    options.markup && jQuery('div#Sidebar').append(options.markup);
  }

})(contactDom);

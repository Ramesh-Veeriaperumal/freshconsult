/*
  DOM manipulation API via message passing.
  Can also be used within an iframe to manipulate parent DOM.
*/
var domHelper = domHelper || {};

(function(dh){

  // cache to prevent multiple hits to helpkit window
  var cache = {};
  var api_data = new jQuery.Deferred();

  api_data.done(function(r){
    cache['json-data'] = r;
  });

  // listen to data provided by helpkit window
  window.addEventListener("message", useData, false);

  function useData(event){
    var id = event.data.id;
    if(id !== 'helpkit-response-data'){return;}
    api_data.resolve(event.data.response);
  }

  // define all the message-interaction mapping
  var message_ids = {
    request_page_details: "request-page-details",
    open_reply: "open-reply-box",
    hide_tkt_delete: "hide-tkt-delete",
    show_tkt_delete: "show-tkt-delete",
    hide_attachments: "hide-attachments",
    show_attachments: "show-attachments",
    trigger_click: "trigger-click",
    trigger_reload: "trigger-reload",
    add_to_dropdown: "add-to-dropdown",
    add_custom_button: "add-custom-button",
    append_to_sidebar: "append-to-sidebar",
    convert_to_agent: "convert-to-agent",
    set_background_info: "set-background-info",
    append_to_contact_sidebar: "append-to-contact-sidebar"
  };

  // Message Data Format
  function dataObj(id, options){
    this.id = id,
    this.options = options || {};
  }

  // Post Message to Top Window
  function notifyHelpkit(message){
    var target_domain = "*"; // using '*' since we have custom target domains
    top.postMessage(message,target_domain);
  }

  init:(function (){
    var options = {};
    var data = new dataObj(message_ids.request_page_details, options)
    notifyHelpkit(data);
  })();

  function getPageInfo(){
    return cache['json-data'];
  }

  // Helper Object Methods (API)
  if(page_type === "ticket"){
    // get current ticket data in json format
    dh.getTicketInfo = function(){
      return getPageInfo();
    }

    // open reply box
    dh.openReply = function(reply_text){
      var options = {};
      if(reply_text) options.content = reply_text;
      var data = new dataObj(message_ids.open_reply, options)
      notifyHelpkit(data);
    }

    // hide ticket delete
    dh.hideTicketDelete = function(){
      var data = new dataObj(message_ids.hide_tkt_delete)
      notifyHelpkit(data);
    }

    // show ticket delete
    dh.showTicketDelete = function(){
      var data = new dataObj(message_ids.show_tkt_delete)
      notifyHelpkit(data);
    }

    // hide attachments
    dh.hideAttachments = function(){
      var data = new dataObj(message_ids.hide_attachments)
      notifyHelpkit(data);
    }

    // show attachments
    dh.showAttachments = function(){
      var data = new dataObj(message_ids.show_attachments)
      notifyHelpkit(data);
    }

    //trigger click on some element
    dh.triggerClick = function(element){
      var options = {};
      if(element) options.element = element;
      var data = new dataObj(message_ids.trigger_click, options)
      notifyHelpkit(data);
    }

    //trigger reload on some element
    dh.triggerReload = function(element){
      var options = {};
      if(element) options.element = element;
      var data = new dataObj(message_ids.trigger_reload, options)
      notifyHelpkit(data);
    }

    //add an option to 'more' dropdown
    dh.addExtraOption = function(anchor_tag){
      var options = {};
      if(anchor_tag){
        options.anchor_tag = anchor_tag;
        var data = new dataObj(message_ids.add_to_dropdown, options)
        notifyHelpkit(data);
      }
    }

    //add custom button in ticket menu
    dh.addCustomButton = function(anchor_tag){
      var options = {};
      if(anchor_tag){
        options.anchor_tag = anchor_tag;
        var data = new dataObj(message_ids.add_custom_button, options)
        notifyHelpkit(data);
      }
    }

    //add custom button in ticket menu
    dh.appendToSidebar = function(markup){
      var options = {};
      if(markup){
        options.markup = markup;
        var data = new dataObj(message_ids.append_to_sidebar, options)
        notifyHelpkit(data);
      }
    }

  }

  if(page_type === "contact"){
    // get current contact data in json format
    dh.getContactInfo = function(){
      return getPageInfo();
    }

    //convert contact to agent
    dh.convertToAgent = function(agent_type){
      var options = {};
      if(agent_type){
        options.agent_type = agent_type;
        var data = new dataObj(message_ids.convert_to_agent, options)
        notifyHelpkit(data);
      }
    }

    //add custom button in ticket menu
    dh.setBackgroundInfo = function(text){
      var options = {};
      if(text){
        options.text = text;
        var data = new dataObj(message_ids.set_background_info, options)
        notifyHelpkit(data);
      }
    }

    //add custom button in ticket menu
    dh.appendToContactSidebar = function(markup){
      var options = {};
      if(markup){
        options.markup = markup;
        var data = new dataObj(message_ids.append_to_contact_sidebar, options)
        notifyHelpkit(data);
      }
    }
    
  }
})(domHelper);

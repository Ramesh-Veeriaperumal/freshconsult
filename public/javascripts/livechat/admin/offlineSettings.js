window.liveChat = window.liveChat || {};

window.liveChat.offlineSettings = function(){
  return {
    setOfflineChatSetting: function(){
      var _widget = window.liveChat.adminSettings.currentWidget;
      if(!_widget['offline_chat']){
        // default offline setting
        window.liveChat.adminSettings.currentWidget.offline_chat = {
          "show": "1",
          "form": { "name"    : CHAT_I18n.name,
                    "email"   : CHAT_I18n.email,
                    "message" : CHAT_I18n.message
                  },
          "messages": {"title": "Leave us a message!",
                       "thank": "Thank you for writing to us. We will get back to you shortly.",
                       "thank_header": "Thank you!"
                      }
        }
      }
    },

    defaultOfflineChat: function(){
      return {
        show 	  : "0",
        form 	  : { "name"        : CHAT_I18n.name, 
                    "email"       : CHAT_I18n.email,
                    "message"     : CHAT_I18n.message
                  },
        messages: { "title" 	    : CHAT_I18n.offline_title,
                    "thank"		    : CHAT_I18n.offline_thank_msg,
                    "thank_header": CHAT_I18n.offline_thank_header_msg  
                  }
      }
    }
  }
}();
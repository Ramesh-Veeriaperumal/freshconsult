window.liveChat = window.liveChat || {};

window.liveChat.offlineSettings = function(){
  return {
    setOfflineChatSetting: function(){
      var _widget = App.Admin.LiveChatAdminSettings.currentWidget;
      if(!_widget['offline_chat']){
        // default offline setting
        App.Admin.LiveChatAdminSettings.currentWidget.offline_chat = _widget.defaultMessages.offline_chat;
      }
    }
  }
}();
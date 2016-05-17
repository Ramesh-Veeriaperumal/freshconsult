window.liveChat = window.liveChat || {};

window.liveChat.offlineSettings = function(){
  return {
    setOfflineChatSetting: function(){
      var _widget = window.liveChat.adminSettings.currentWidget;
      if(!_widget['offline_chat']){
        // default offline setting
        window.liveChat.adminSettings.currentWidget.offline_chat = _widget.defaultMessages.offline_chat;
      }
    }
  }
}();
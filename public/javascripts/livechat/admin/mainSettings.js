window.liveChat = window.liveChat || {};

window.liveChat.mainSettings = function($){
  return {  
    getSiteSettings: function(){
      var request = { action: "sites/get" };
      request.data = "&siteId=" + window.SITE_ID + "&userId=" + CURRENT_USER.id + "&token=" + LIVECHAT_TOKEN ;
      window.liveChat.jsonpRequest(request, function (resp){
        if(resp.status == "success"){
          $('.fc-mxc-count span').html(resp.result.site.max_chat);
        }
       });
    },

    toggleSite: function(toggledState){
      var asset_url = ASSET_URL;
      var js_asset_url = asset_url.js;
      
      if(window.location && window.location.protocol=='https:'){
        js_asset_url = asset_url.cloudfront;
      }

      var data = {	
        "siteId"   : window.SITE_ID, 
        "domain"   : CURRENT_ACCOUNT.domain, 
        "url"      : window.location.hostname, 
        "protocol" : window.location.protocol,
        "status"   : toggledState,
        "userId"   : CURRENT_USER.id,
        "token"    : window.LIVECHAT_TOKEN
      };

      $.ajax({
        type: "POST",
        url: window.liveChat.URL + "/sites/toggle",
        data: data,
        dataType: "json",
        success: function(resp){
          if(resp.status == "success"){
            if(toggledState){
              $('#chat_widgets_list').removeClass("disable-widgets");
              if($('#livechat_layout') && window.chatSocket){
                $('#livechat_layout,#chat-availability').show();
                window.chatSocket.connect();
              }else{
                $('body').append('<div id="livechat_layout" class="fc-layout"></div>');
                $.getScript(js_asset_url+"/js/chat.js");
              }
            }else{
              $('#chat_widgets_list').addClass("disable-widgets");
              $('#livechat_layout,#chat-availability').hide();
              if(window.chatSocket){
                window.chatSocket.disconnect();
              }
            }
          }
        }
      });
    },

    updateSite: function(attributesToBeUpdated){
      var self = this;
      var data = 	{	
        "siteId" 		: window.SITE_ID, 
        "attributes": attributesToBeUpdated,
        "userId"		: CURRENT_USER.id,
        "token"			: LIVECHAT_TOKEN
      };
      $.ajax({
        type: "POST",
        url: window.liveChat.URL + "/sites/update",
        data: data,
        dataType: "json",
        success: function(response){
          if(response.status == "success"){
            $('.fc-mxc-count').removeClass('show');
            $('.fc-mxc-options').removeClass('sloading');
            $('.fc-mxchat').removeClass('editing');
            self.showMsg(response);
          }
        }
      });
    },

    renderWidget: function(){
      var self = this;
      self.getLiveChatWidgetSettings(function(response){
        if(response.status == "success"){
          $('#chat_loading').hide();
          $('#chat_setting').show();
          var _widget = window.liveChat.adminSettings.currentWidget;
          window.liveChat.adminSettings.currentWidget = $.extend({}, _widget, response.result);
          self.parseStringJsonFields();
          window.liveChat.offlineSettings.setOfflineChatSetting();
          self._renderWidget();
        }        
      });
    },

    getLiveChatWidgetSettings: function(callback){
      var _widget = window.liveChat.adminSettings.currentWidget;
      var request = { action: "widgets/get" };
      request.data = "&siteId=" + _widget.fc_id + "&widget_id="+_widget.widget_id + "&userId=" + CURRENT_USER.id + "&token=" + LIVECHAT_TOKEN;
      window.liveChat.jsonpRequest(request, function (response){
        callback(response);
      });
    },

    parseStringJsonFields: function(){
      var _widget = window.liveChat.adminSettings.currentWidget;
      var serializedFields = ['widget_preferences','non_availability_message',
                              'prechat_fields','business_calendar','routing','offline_chat'];
      $.each(serializedFields, function(index, field){
        if(typeof _widget[field] == 'string'){
          window.liveChat.adminSettings.currentWidget[field] = JSON.parse(_widget[field]);
        }
      });
    },

    toggleWidget: function(toggledState, widget_id){
      var self = this;
      var _widgetList = window.liveChat.adminSettings.widgetList;
      var _widget = window.liveChat.adminSettings.currentWidget;
      var widget_id = (widget_id || _widget.widget_id)
      var data = {	
        "siteId" 	  : window.SITE_ID, 
        "domain"	  : CURRENT_ACCOUNT.domain, 
        "url"		    : window.location.hostname , 
        "protocol" 	: window.location.protocol,
        "status" 	  : toggledState,
        "widget_id"	: widget_id,
        "userId"	  : CURRENT_USER.id,
        "token"		  : LIVECHAT_TOKEN
      };
      $.ajax({
        type: "POST",
        url: window.liveChat.URL + "/widgets/toggle",
        data: data,
        dataType: "json",
        success: function(response){}
      });
    },

    createWidget: function(triggeredFrom){
      var self = this;
      var _widget = window.liveChat.adminSettings.currentWidget;
      var _widgetList = window.liveChat.adminSettings.widgetList;
      var data = {  
                    "id"                : CURRENT_ACCOUNT.id, 
                    "siteId"            : window.SITE_ID,
                    "domain"            : CURRENT_ACCOUNT.domain, 
                    "url"               : window.location.hostname , 
                    "protocol"          : window.location.protocol, 
                    "active"            : _widget.active || false,
                    "external_id"       : _widget.product_id || "",
                    "site_url"          : _widget.widget_site_url,
                    "name"              : _widget.name,
                    "prechat_message"   : CHAT_I18n.prechat_message,
                    "widget_preferences": window.liveChat.widgetSettings.defaultWidgetMessages(),
                    "prechat_fields"    : window.liveChat.visitorFormSettings.defaultPrechatFields(),
                    "token"             : LIVECHAT_TOKEN,
                    "userId"            : CURRENT_USER.id,
                    "non_availability_message" : window.liveChat.widgetSettings.defaultNonAvailabilitySettings(),
                    "offline_chat"      : window.liveChat.offlineSettings.defaultOfflineChat()
                 };
      $.ajax({
        type: "POST",
        url: window.liveChat.URL + "/widgets/create",
        data: data,
        dataType: "json",
        success: function(response){
          if(response.status == "success"){
            if(triggeredFrom == "edit"){
              $('#chat_loading').hide();
              $('#chat_setting').show();
              window.liveChat.adminSettings.currentWidget = $.extend({}, _widget, response.result);
              self.parseStringJsonFields();
              self._renderWidget();
            }else if(triggeredFrom == "index"){
              for(var i=0; i < _widgetList.length; i++){
                if(_widgetList[i].product_id == response.result.product_id){
                  _widgetList[i].widget_id = response.result.widget_id;
                }
              }
              if($('#livechat_layout') && window.chatSocket){
                $('#livechat_layout, #chat-availability').show();
                window.chatSocket.connect();
              }
            }
          }
        }
      });
    },

    _renderWidget: function(){
      window.liveChat.widgetSettings.render();
      window.liveChat.visitorFormSettings.render();
      window.liveChat.preferenceSettings.render();
      window.liveChat.widgetSettings.bindEvents();
    },

    showMsg: function(response){
      $(".chat_setting_save").removeAttr('disabled');
      var msg = '';
      if(resp.status == "error"){
        if(resp.msg){
          msg = resp.msg;
        }else{
          msg = CHAT_I18n.update_error_msg;
        }
        window.liveChat.widgetSettings.pendingChanges = true;
      }else{
        msg = CHAT_I18n.update_success_msg;
        window.liveChat.widgetSettings.pendingChanges = false;
      }

      $("#chat_settings_notice").text(msg).show();
      closeableFlash('#chat_settings_notice');
      $('html,body').animate({scrollTop: 220}, 800);
    },

    bindMaxChatEvents: function(){
    	var previousValue;
      var self = this;

    	$('body').on('click',function(){
    		if($('.fc-mxc-count').hasClass('show')){
    			$('.fc-mxc-count').removeClass('show');
    		}
    	});
      $(".fc-mxc-edit").on('click', function(){
    		previousValue = $('.fc-mxc-count span').text();
    		$('.fc-mxchat').addClass('editing');
    	});
      $(".fc-mxc-count span").on('click', function(evt){
    		evt.stopPropagation();
    		if($('.fc-mxchat').hasClass('editing')){
    			$('.fc-mxc-count').addClass('show');
    		}
    	});
      $(".fc-mxc-count ul li").on('click', function(){
    		$('.fc-mxc-count span').html($(this).val());
    		$('.fc-mxc-count').removeClass('show');
    	});
      $(".fc-mxc-save .icon-tick").on('click', function(){
    		$('.fc-mxc-options').addClass('sloading');
    		var data = {};
    		data.max_chat = $('.fc-mxc-count span').text();
    		self.updateSite(data);
    	});
      $(".fc-mxc-cancel").on('click', function(){
    		$('.fc-mxc-count span').html(previousValue);
    		$('.fc-mxc-count').removeClass('show');
    		$('.fc-mxchat').removeClass('editing');
    	});
    }
  }
}(jQuery);
window.liveChat = window.liveChat || {};

window.liveChat.mainSettings = function($){
  return {  
    getSiteSettings: function(){
      window.liveChat.request('sites/' + window.SITE_ID, 'GET', {}, function(err, resp) {
        if(resp){
          $('.fc-mxc-count span').html(resp.max_chat);
          if(resp.cobrowsing){
            window.fc_cobrowsing = resp.cobrowsing;
            $("#chat_cobrowsing").prop('checked', true);  
            $("#chat_cobrowsing").trigger('change'); 
          }else{
            window.fc_cobrowsing = false;
            $("#chat_cobrowsing").prop('checked', false);
            $("#chat_cobrowsing").trigger('change');
          }
        }
      });
    },

    toggleSite: function(toggledState){
      var asset_url = ASSET_URL;
      var js_asset_url = asset_url.js;
      $.ajax({
        type: "PUT",
        url: "/livechat/toggle",
        data: { attributes: { active : toggledState } },
        dataType: "json", 
        success: function(resp){
          if(resp.status == "success"){
            if(toggledState){
              $('#chat_widgets_list').removeClass("disable-widgets");
              if($('#livechat_layout') && window.liveChat.clientWrapper){
                $('#livechat_layout,#chat-availability').show();
                window.liveChat.clientWrapper.connectPrimaryClient();
              }else{
                $('body').append('<div id="livechat_layout" class="fc-layout"></div>');
                $.getScript(js_asset_url+"/js/chat.js");
              }
            }else{
              $('#chat_widgets_list').addClass("disable-widgets");
              $('#livechat_layout,#chat-availability').hide();
              if(window.liveChat.clientWrapper){
                window.liveChat.clientWrapper.disconnectPrimaryClient();
              }
            }
          }
        }
      });
    },

    updateSite: function(attributesToBeUpdated){
      var self = this;
      $.ajax({
        type: "PUT",
        url: "/livechat/update_site",
        data: { attributes: attributesToBeUpdated },
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
      self.getLiveChatWidgetSettings(function(err, response){
        $('#chat_loading').hide();
        $('#chat_setting').show();
        var _widget = window.liveChat.adminSettings.currentWidget;
        delete response.id;
        window.liveChat.adminSettings.currentWidget = $.extend({}, _widget, response);
        self.parseStringJsonFields();
        window.liveChat.offlineSettings.setOfflineChatSetting();
        self._renderWidget();
      });
    },

    getLiveChatWidgetSettings: function(callback){
      var _widget = window.liveChat.adminSettings.currentWidget;
      window.liveChat.request('widgets/' + _widget.widget_id, 'GET', {}, callback);
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
      $.ajax({
        type: "POST",
        url: "/admin/chat_widgets/toggle",
        data: { attributes : { active : toggledState }, widget_id : widget_id, id: _widget.id },
        dataType: "json",
        success: function(response){}
      });
    },

    createWidget: function(triggeredFrom){
      var self = this;
      var _widget = window.liveChat.adminSettings.currentWidget;
      var _widgetList = window.liveChat.adminSettings.widgetList;
      $.ajax({
        type: "POST",
        url: "/admin/chat_widgets/enable",
        data: { product_id: _widget.product_id, active: triggeredFrom == "index" },
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
                if(_widgetList[i].product_id == _widget.product_id){
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

    showMsg: function(resp){
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
      $('html,body').animate({scrollTop: 0});
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
    },
    bindCobrowsingSetting: function(){
      var self = this;
      $('#chat_cobrowsing').on('change', function (){
        if($("#chat_enable").is(":checked")){
          var status = $(this).is(":checked") ? true : false;
          if (status == window.fc_cobrowsing){
            return;
          }
          window.fc_cobrowsing = status;
          var data = {};
          data.cobrowsing = status;
          self.updateSite(data);
        }
      });
    }
  }
}(jQuery);
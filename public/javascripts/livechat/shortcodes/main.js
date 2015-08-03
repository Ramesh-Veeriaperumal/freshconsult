var liveChat = liveChat || { };

liveChat.admin_short_codes = (function(){
    "use strict";
    var _module =  {
      _new_code_dom_fragment : window.JST["livechat/templates/shortcodes/shortCodes"],
      _auth_params: null,
      _action_urls: {
          create   : { type: "POST", url: "shortcodes/create"},
          getCodes : {type: "GET", url: "shortcodes/getCodes"},
          update   : {type: "POST", url: "shortcodes/update"},
          destroy  : {type: "POST", url: "shortcodes/destroy"}
      },
      _error_messages: {
          CODE_EMPTY : "Code cannot be empty.",
          ER_DUP_ENTRY : "Trying to add or update duplicate code.",
          
        },
      _trim_size: 45,
      _valid_code: new RegExp((/[`~,.<_>;':"/[\]|{}()!@#$%^&*?=\s+]/)),
      bindEvents: function(){
        jQuery('#short_code_add').click(function(){
          if(jQuery("ul.fc-shortcodes li[data-action='create']").length >0 ){
            jQuery("ul.fc-shortcodes li[data-action='create'] input.short_code_key").focus();
            return false;
          }
          var _random_id = "new_" + _module.getRandomInt(1,10);
          var _new_fragment = _module._new_code_dom_fragment({dom_class: "editing", dom_action: "create", short_code_id: _random_id, code: "", message: "", i18n: _module.i18n});
          jQuery('#short_codes_container').prepend(_new_fragment);
          jQuery("#"+_random_id).find(".short_code_key").focus();
          jQuery(this).addClass('disabled');
        });

        jQuery('.canned-response-tabs a').click(function(e) {
          e.preventDefault();
          history.pushState( null, null, jQuery(this).attr('href') );
          jQuery(this).tab('show');
          if(jQuery(this).attr('id') === 'cannedResponses_btn'){
            jQuery('.sc-new-btn, #chatShortcodes_help').addClass('hide');
            jQuery('.cr-new-btn, #cannedResponses_help').removeClass('hide');
          }
          else{
            jQuery('.sc-new-btn, #chatShortcodes_help').removeClass('hide');
            jQuery('.cr-new-btn, #cannedResponses_help').addClass('hide');
          }
        });

        jQuery('.fc-sc-edit').live('click',function(){
          jQuery(this).parents('.fc-item').addClass('editing').removeClass("error");
        });

        jQuery('.fc-sc-save').live('click',function(){
          var _parent = jQuery(this).parents('.fc-item');
          var _key = _parent.find('.short_code_key').val();
          var _message = _parent.find('.short_code_message').val();
          var _params = {};

          if(!_module.validateCode(_key.trim())){
            _module.showAlertMsg(_parent,_module._error_messages.CODE_EMPTY);
            return false;
          }

          _params.data = {site_id : window.SITE_ID, code: _key, message: _message};
          _params.selector_id = _parent.attr("id");
          _params.action = _module._action_urls.update;

          if(_parent.attr("data-action") == 'update'){
            _params.data.id = _parent.attr("id");
            _module.ajaxCall(_params,_module.updateShortCodeId,_parent);
          }else{
            _params.action = _module._action_urls.create;
            _module.ajaxCall(_params,_module.createShortCodeId,_parent);
          }
        });

        jQuery('.fc-sc-discard').live('click',function(){
          var _parent = jQuery(this).parents('.fc-item');
          if(!jQuery.isNumeric(_parent.attr("id"))){
            jQuery('#short_code_add').removeClass('disabled');
            _parent.remove();
            return;
          }
          _parent.removeClass("error");
          _parent.find(".error-label").remove();
          _parent.find(".short_code_key").val(_parent.find(".code_view").text());
          _parent.find(".short_code_message").val(_parent.find(".message_view").text());
          _parent.removeClass('editing');
        });

        jQuery('.fc-sc-delete').live('click',function(){
          if(window.confirm(_module.i18n.confirm)){
            var _parent = jQuery(this).parents('.fc-item'),
                _params = {},
                _code_id =  _parent.attr("id");
            _params.action = _module._action_urls.destroy;
            _params.data = {site_id : window.SITE_ID, id: _code_id};
            _params.selector_id = _parent.attr("id");
            _module.ajaxCall(_params,_module.deleteShortCode,_parent);
          }          
        });


      },

      getCodes: function(){
        var _params = {
          action: _module._action_urls.getCodes,
          data: {site_id : window.SITE_ID},
          dataType: "jsonp",
          selector_id: "short_codes_container"
        };
        _module.ajaxCall(_params,_module.buildDom,[]);
      },

      //delete code callback
      deleteShortCode: function(resp,short_code_id){
        jQuery("#"+short_code_id).remove();
      },
      //create new record callback
      createShortCodeId: function(resp,short_code_id){
        var _parent_elm = jQuery("#"+short_code_id).attr("id",resp.result.id).attr("data-action","update");
        _parent_elm.find(".code_view").html(resp.result.code);
        _parent_elm.find(".message_view").html(escapeHtml(resp.result.message));
        _parent_elm.find(".error-label").remove();
        _parent_elm.removeClass('editing');
        _parent_elm.find('.short_code_key').val(resp.result.code);
        _parent_elm.find('.short_code_message').val(resp.result.message);
        jQuery('#short_code_add').removeClass('disabled');
      },
      //update record callback
      updateShortCodeId: function(resp,short_code_id){
        var _parent_elm = jQuery("#"+short_code_id);
        _parent_elm.find(".code_view").html(_parent_elm.find('.short_code_key').val());
        _parent_elm.find(".message_view").html(escapeHtml(_parent_elm.find('.short_code_message').val()));
        _parent_elm.find(".error-label").remove();
        _parent_elm.removeClass('editing');
      },
      //get records call back
      buildDom: function(resp,container_id){
        var _dom_fragment = "";
        var _short_codes = resp.result;
        var _container_elm = jQuery("#"+container_id);
        for (var i=0; i < _short_codes.length; i++){
          var _code_obj = _short_codes[i];
          _dom_fragment += _module._new_code_dom_fragment({dom_class: "", dom_action: "update", short_code_id: _code_obj.id, code: _code_obj.code, message: _code_obj.message, i18n: _module.i18n})
        }
        _container_elm.html(_dom_fragment);
      },

      validateCode: function(code){
        return (code.length > 0 && code.length <= 10 && !_module._valid_code.test(code));
      },

      showAlertMsg: function(elem, msg){
        elem.find(".error-label").remove();
        elem.append("<span class='error-label'>"+msg+"</span>");
        elem.addClass("error");
      },

      getRandomInt: function(min, max) {
        return Math.floor(Math.random() * (max - min)) + min;
      },

      trimData: function(str){
        var _str = (str.length > _module._trim_size) ? str.substring(0,_module._trim_size)+"..." : str;
        return _str;
      },

      ajaxCall: function(params,callback,parent_elem){
        parent_elem.length > 0 ? parent_elem.addClass("sloading") : "";
        params.data.user_id = _module._auth_params.user_id;
        params.data.token = _module._auth_params.token;
        jQuery.ajax({
          type: params.action.type,
          url: window.csURL + "/" + params.action.url,
          data: params.data,
          dataType: params.dataType ? params.dataType : "json",
          cache: false,
          success: function( response ) {
              if(response.status == 'success' && _.isFunction(callback)){
                  callback(response,params.selector_id);
                  parent_elem.length > 0 ? parent_elem.removeClass("sloading") : "";
              }
              else if(response.status == 'error'){
                var _msg = _module._error_messages[response.error_message.error_code];
                _module.showAlertMsg(parent_elem,_msg);
                parent_elem.length > 0 ? parent_elem.removeClass("sloading") : "";
              }
          },
          error: function (httpReq, status, exception) {
              console.log("error getting " +params.action, exception);
              _module.showAlertMsg(parent_elem,exception);
          }
        });
      }
    };

    return {
      init: function(opts){
        if(typeof CHAT_ENV != 'undefined' && CHAT_ENV == 'development'){
          window.csURL = "http://"+CS_URL+":4000"; 
        }else{
          window.csURL = "https://"+CS_URL+":443";
          if(window.location && window.location.protocol=="http:" && (window.liveChat.ieVersionCompatability() || FC_HTTP_ONLY)){
            window.csURL = "http://"+CS_URL+":80";
          } 
        }
        if(opts._i18n_msg){
          _module._error_messages = opts._i18n_msg.error_msg;  
          _module.i18n =  {code: opts._i18n_msg.title, message: opts._i18n_msg.message, confirm: opts._i18n_msg.confirm};
        }
        _module._auth_params = { user_id: opts._agent_id, token: opts._token};
        _module.bindEvents();
        _module.getCodes();
      }
   };
})();
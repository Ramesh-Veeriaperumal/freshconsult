window.liveChat = window.liveChat || {};

window.liveChat.widgetCode = function($){
	return {
		bindClipBoardEvents: function(){
			var self = this;
			var asset_url = ASSET_URL;
			var js_asset_url = asset_url.js;

			if(window.location && window.location.protocol=='https:'){
				js_asset_url = asset_url.cloudfront;
			}

			ZeroClipboard.config({ debug: false });

			var clip = new ZeroClipboard($('.chat_code_copy'), {
				moviePath: zeroClipBoardSWFPath
			});

			clip.on( 'dataRequested', function ( client, args ) {
				clip.setText($("#EmbedCode").val());
			});

			clip.on({
				complete: function(client, args){
					$('.chat_code_copy').attr('data-original-title', CHAT_I18n.copied);
					$('.chat_code_copy').twipsy('show');
					$("#EmbedCode").select();    
					$("#EmbedCode").removeClass("code_fade_effect");
				},
				mouseover: function(client, args){
					$('.chat_code_copy').attr('data-original-title', CHAT_I18n.copy_to_clipboard);
					$('.chat_code_copy').twipsy('show');
					self.removeSelect();
				},
				mouseout: function(client, args){
					$('.chat_code_copy').twipsy('hide');
				}
			});

			clip.on('noflash wrongflash', function(client) {
				$('.chat_code_copy').hide();
			});

			$("#EmbedCode").on('click', function(){
				$(this).select().removeClass("code_fade_effect");
			});
		},

		updateCode: function(){
			var _widget = window.liveChat.adminSettings.currentWidget;
      var asset_url = ASSET_URL;

			var url1 		= asset_url.cloudfront;
			var code 		= "var fc_CSS=document.createElement('link');fc_CSS.setAttribute('rel','stylesheet');"+
					"var isSecured = (window.location && window.location.protocol == 'https:');"+
					"var rtlSuffix = ((document.getElementsByTagName('html')[0].getAttribute('lang')) === 'ar') ? '-rtl' : '';"+
					"fc_CSS.setAttribute('type','text/css');fc_CSS.setAttribute('href',((isSecured)? '"+url1+"':'"+asset_url.css+
					"')+'/css/visitor'+rtlSuffix+'.css');"+"document.getElementsByTagName('head')[0].appendChild(fc_CSS);"+
					"var fc_JS=document.createElement('script'); fc_JS.type='text/javascript';"+
					"fc_JS.src=((isSecured)?'"+url1+"':'"+asset_url.js+"')+'/js/visitor.js';"+ 
					"(document.body?document.body:document.getElementsByTagName('head')[0]).appendChild(fc_JS);"+
					"window.freshchat_setting= '"+Base64.encode(JSON.stringify(_widget))+"';";

			$("#EmbedCode").val("<script type='text/javascript'>"+code+"<"+"/script>");
		},

		removeSelect: function(){
			if (window.getSelection) {
				if (window.getSelection().empty) {
					window.getSelection().empty();
				} else if (window.getSelection().removeAllRanges) {
					window.getSelection().removeAllRanges();
				}
			} else if (document.selection) {
				document.selection.empty();
			}
		}
	}
}(jQuery);
define([
  'text!templates/chat/tag-this.html'   
], function(tagTemplate){  
	var $ = jQuery;
	var tagView = Backbone.View.extend({		
		isOpen: false,
		render:function(data){
				var that = this;
				var etags = (data.tags)?data.tags:[];
				if(!that.isOpen){
					that.isOpen = true;
					$('body').append(_.template(tagTemplate,{tags:etags}));
					$('.closeDialog, .cancelBtn').on('click', function(){
						that.isOpen = false;
						$('#tag-this').remove();
						$('div.select2-drop').remove();
					});
					$('#save_tag').on('click', function(){
						var tags = $("#e12").select2("val");
						chat_socket.emit('tag',{
							chatid: data.chatid,
							tags: tags
						});
						chat_socket.once('tag',function(data){						
							that.isOpen = false;
							$('#tag-this').remove();
							$('div.select2-drop').remove();
						});
					});
				}
		}
	});
	return 	(new tagView());
});
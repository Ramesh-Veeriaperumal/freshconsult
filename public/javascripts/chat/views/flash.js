
define([
  'collections/flash',
  'text!templates/flash.html'
], function(FlashCollection,flashTemplate){
      var $ = jQuery;
	var FlashView = Backbone.View.extend({
		render: function(flashContent){
			if(!this.flashCollections){
				this.flashCollections = new FlashCollection();
			}
			var that = this;
			flash = this.flashCollections.addNew(flashContent);
        	var msgDiv = $('<div>');
			msgDiv.attr('id',flash.id);
			msgDiv.addClass(flashContent.classname);
			var top = that.getTop();
			msgDiv.css({'top': top+'px'});
			$(document.body).append(msgDiv.html(_.template(flashTemplate,{"flash":flashContent})));
			$(msgDiv).find(".close-btn").on('click',function(){
				$(msgDiv).slideUp('slow', function(){
					$(msgDiv).remove();
				})
				that.flashCollections.remove(flash);
			});
			$(msgDiv).slideDown('slow');
			return flash;
    	},
    	getTop : function(){
    		var collections = this.flashCollections.length-1;
    		if(collections == 0){
    			return 0;
    		}else{
    			var flash = this.flashCollections.at(collections-1),
    				id = flash.id;
    			return $("#"+id).offset().top+$("#"+id).height()+24;
    		}
    	},
    	removeFlash : function(flash){
    		if(!flash){
    			return;
    		}
    		$("#"+flash.id).remove();
    		this.flashCollections.remove(flash);
    	}
	});
	return new FlashView();
});
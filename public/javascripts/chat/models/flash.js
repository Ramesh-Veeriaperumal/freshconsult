define([], 
	function(){
		var FlashModel = Backbone.Model.extend({
			constructor:function(){
				this.id = "flash_"+(new Date()).getTime();		
			}
	});
	return FlashModel;
});
define([    
    'models/flash'
],
function(Flash){
    var FlashCollection = Backbone.Collection.extend({
        model: Flash,
        url:"javascript:void();",
        addNew : function(flashs){
            flash = this.create(flashs);
		    this.add(flash);
		    return flash;
        },
        removeAll : function(){
    	   var that = this;
            var collections = this.length;
            for (var i = collections-1 ; i >= 0; i--) {
                var flash = that.at(i);
                $("#"+flash.id).remove();
                that.remove(flash);
            }
    	}
    });
    return FlashCollection;
});
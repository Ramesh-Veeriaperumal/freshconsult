Ext.define('plugin.ux.TitleDoubleTap', {
	extend: 'Ext.Component',
	alias: 'plugin.titleDoubleTap',
	config: {
		action:'goToTop'
	},
	initialize: function() {
	  this.callParent();
	},
	init : function(list) {
		var self = this;
		self.list = list;
		list.on({
			painted : {
				fn: function(){
					var titleBarId = this.list && this.getTitleBarId(this.list),
							listview = this.list && this.getListView(this.list);
					this.listview = listview;
					Ext.get(titleBarId).on({
						doubletap: {
							fn: function(){
								this[this.getAction()].apply(this,[listview])
							},
							scope:this
						}
					})
				},
				scope: this
			}
		})
	},

	getTitleBarId : function(list){
		if(list.items && list.items.items && list.items.items[0])
		 	return list.items.items[0].id;
	},

	getListView : function(list){
		if(list.items && list.items.items && list.items.items[1])
		 	return list.items.items[1];
	},

	goToTop : function(listview) {
		var scroller = listview.getScrollable().getScroller();
			scroller.scrollToTop(true);
	},

	pageUp : function(listview) {
		var scroller = listview.getScrollable().getScroller();
			scroller.scrollTo(0,scroller.position.y-(Ext.Viewport.windowHeight-46),true);
	}

});

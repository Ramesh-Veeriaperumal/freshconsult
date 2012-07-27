Ext.define('plugin.ux.Iscroll', {
    extend: 'Ext.Component',
    alias: 'plugin.iscroll',
    requires:'Ext.util.DelayedTask',
    config: {
    	list : null,
    },
    initialize: function() {
        this.callParent();
    },
	init : function(list){
		var me = this;
		me.list = list;
		this.list.on({
			painted:function(){
				this.registerIscroll();
			},
			scope:this
		})
	},
	registerIscroll : function(){
		this._updateIScroll();
	},
	getIScrollElementId : function() {
		return this.list.bodyElement.getId();
	},
	_ensureIScroll: function() {
		if (!this.iScroll) {
			var el = this.getIScrollElementId();
			this.iScroll = new iScroll(el);
			this.iScrollTask = new Ext.util.DelayedTask(this._refreshIScroll, this);
		}
	},
	_updateIScroll: function() {
		this._ensureIScroll();
		if (this.iScroll) {
			this.iScrollTask.delay(1000);
		}
	},
	_refreshIScroll: function() {
		this.iScroll.refresh();
		//Refresh one more time.
		this.iScrollTask.delay(1000);
	}
});
// Ext.override(Ext.Panel, {
// 	afterRender: Ext.Panel.prototype.afterRender.createSequence(function() {
// 		if (this.getXType() == 'panel') {
// 			this._getIScrollElement = function() {
// 				return (this.el.child('.x-panel-body', true));
// 			}
// 		}

// 		//Uncomment below to use iScroll only on mobile devices but use regular scrolling on PCs.
// 		if (this.autoScroll /*&& Ext.isMobileDevice*/) {
// 			if (this._getIScrollElement) {
// 				this._updateIScroll();
// 				this.on('afterlayout', this._updateIScroll);
// 			}
// 		}
// 	}),

// 	_ensureIScroll: function() {
// 		if (!this.iScroll) {
// 			var el = this._getIScrollElement();
// 			if (el.children.length > 0) {
// 				this.iScroll = new iScroll(el);
// 				this.iScrollTask = new Ext.util.DelayedTask(this._refreshIScroll, this);
// 			}
// 		}
// 	},

// 	_updateIScroll: function() {
// 		this._ensureIScroll();
// 		if (this.iScroll) {
// 			this.iScrollTask.delay(1000);
// 		}
// 	},

// 	_refreshIScroll: function() {
// 		this.iScroll.refresh();
// 		//Refresh one more time.
// 		this.iScrollTask.delay(1000);
// 	}
// });

// Ext.override(Ext.tree.TreePanel, {
// 	_getIScrollElement: function() {
// 		return (this.el.child('.x-panel-body', true));
// 	}
// });

// Ext.override(Ext.grid.GridPanel, {
// 	_getIScrollElement: function() {
// 		return (this.el.child('.x-grid3-scroller', true));
// 	},

// 	afterRender: Ext.grid.GridPanel.prototype.afterRender.createSequence(function() {
// 		//TODO: need to hook into more events and to update iScroll.
// 		this.view.on('refresh', this._updateIScroll, this);
// 	})
// });
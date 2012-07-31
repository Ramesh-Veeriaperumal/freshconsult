Ext.define('Freshdesk.view.FlashMessageBox', {
    extend: 'Ext.Container',
    alias: 'widget.flashMessageBox',
    initialize: function () {
        this.callParent(arguments);
        var me =this;

        var backButton = {
            xtype:'button',
            text:'Close',
			ui:'lightBtn back',
            handler:this.goBack,
			align:'left',
            scope:this
		};
		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            title:'Results',
            ui:'header',
			items: [backButton]
		};

        var details = {
            tpl : new Ext.XTemplate(['<div class="flash">',
                        '<tpl if="title"><div><div class="icon-scenario"></div><div class="scenario-text">{title}</div></div></tpl>',
                        '<tpl for="messages">',
                            '<div><div class="icon-message"></div><div class="scenario-text">{.}</div></div>',
                        '</tpl>',
                    '</div>'
            ].join('')),
            data : { 
                title : 'Executed scenario <b>Assign to QA</b>',
                messages : [
                        'Changed the ticket type to <b>Problem</b>',
                        'Set group as <b>QA</b>'
                ]
            }
        };
        this.add([topToolbar,details]);
    },
    goBack : function(){
        this.hide();
        if(this.hideHandler){
            this.hideHandler();            
        }
    },
    config: {
        layout:'fit',
        scrollable:true,
        cls:'flashMessageBox',
        id:'flashMessageBox',
        zIndex:10,
        showAnimation : {
            type:'slideIn',
            direction:'down',
            easing:'ease-in-out'
        },
        hideAnimation: {
                type:'slideOut',
                direction:'down',
                easing:'ease-in-out'
        }
    }
});

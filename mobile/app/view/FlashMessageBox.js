Ext.define('Freshdesk.view.FlashMessageBox', {
    extend: 'Ext.Container',
    alias: 'widget.flashMessageBox',
    initialize: function () {
        this.callParent(arguments);
        var me =this;

        var backButton = {
            xtype:'button',
            text:'Hide',
			ui:'lightBtn back',
            handler:this.goBack,
			align:'left',
            scope:this
		};
		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            ui:'header',
			items: [backButton]
		};

        var details = {
            tpl : new Ext.XTemplate(['<div class="flash">',
                        '<tpl if="title"><div>{title}</div></tpl>',
                        '<tpl for="messages">',
                            '<div class="message">{.}</div>',
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
        if(this.hideHandler){
            this.hide();
            this.hideHandler();            
        }else{
            this.hide();
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

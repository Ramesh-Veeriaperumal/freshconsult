Ext.define("Freshdesk.view.Solutions", {
    extend: "Ext.Container",
    alias: "widget.solutions",
    onSolutionDisclose : function(article){
        var replyFormContainer = Ext.ComponentQuery.query('#ticketReplyForm')[0], 
        ticket_id = replyFormContainer.ticket_id,
        messageElm  = replyFormContainer.getMessageItem();
        messageElm.setValue(messageElm.getValue()+article.textile_desc);
        this.hide();
    },
    config: {
        itemId : 'solutionsPopup',
        cls:'solution',
        zIndex:10,
        showAnimation: {
                type:'slideIn',
                direction:'up',
                easing:'ease-in-out'
        },
        hideAnimation: {
                type:'slideOut',
                direction:'down',
                easing:'ease-in-out'
        },
        layout:'fit',
        hidden:true,
        items :[
        {
                xtype:'list',
                emptyText: '<div class="empty-list-text">We couldn\'t find any related solutions.</div>',
                onItemDisclosure: false,
                deferEmptyText:false,
                itemTpl: '<span class="bullet"></span>&nbsp;{title}'
        },
        {
            xtype:'titlebar',
            title:'Pick Solution',
            ui:'header',
            docked:'top',
            items:[
                    {
                        xtype:'button',
                        ui:'plain lightBtn',
                        iconMask:true,
                        align:'left',
                        text:'Cancel',
                        handler:function(){
                            Ext.ComponentQuery.query('#solutionsPopup')[0].hide();
                        },
                        scope:this
                    },
                    {
                        xtype:'button',
                        ui:'plain headerBtn',
                        iconMask:true,
                        align:'right',
                        text:'Insert',
                        handler:function(){
                            var me = Ext.ComponentQuery.query('#solutionsPopup')[0],
                            selection = me.items.items[0].getSelection();
                            if(selection.length) 
                                me.onSolutionDisclose(selection[0].raw)

                        },
                        scope:this
                    }
            ]
        }
        ]
    }
});
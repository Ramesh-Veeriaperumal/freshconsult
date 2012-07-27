Ext.define("Freshdesk.view.Solutions", {
    extend: "Ext.Container",
    alias: "widget.solutions",
    onSolutionDisclose : function(list, index, target, record, evt, options){
        var ca_resp_id = record.raw.id,
        replyFormContainer = Ext.ComponentQuery.query('#ticketReplyForm')[0], 
        ticket_id = replyFormContainer.ticket_id,
        messageElm  = replyFormContainer.getMessageItem();
        messageElm.setValue(messageElm.getValue()+record.raw.article.desc_un_html);
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
                emptyText: '<div class="empty-list-text">You don\'t have any suggested solutions!.</div>',
                onItemDisclosure: false,
                deferEmptyText:false,
                itemTpl: '<span class="bullet"></span>&nbsp;{article.title}',
                listeners:{
                        itemtap:{
                            fn:function(){
                                this.parent.onSolutionDisclose.apply(this.parent,arguments);
                            }
                        }
                }
        },
        {
            xtype:'titlebar',
            title:'Solution',
            ui:'header',
            docked:'top',
            items:[
                {
                    xtype:'button',
                    ui:'plain',
                    iconCls:'delete_black2',
                    iconMask:true,
                    align:'right',
                    handler:function(){
                        Ext.ComponentQuery.query('#solutionsPopup')[0].hide();
                    },
                    scope:this
                }
            ]
        }
        ]
    }
});
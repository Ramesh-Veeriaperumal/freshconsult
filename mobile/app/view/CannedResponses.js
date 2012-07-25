Ext.define("Freshdesk.view.CannedResponses", {
    extend: "Ext.Container",
    alias: "widget.cannedResponses",
    populateMessage : function(res){
        var content = res.responseText,msgFormContainer = Ext.ComponentQuery.query('#'+this.formContainerId)[0],
        messageElm  = msgFormContainer.getMessageItem();
        messageElm.setValue(messageElm.getValue()+content);
        this.hide();
    },
    onCannedResDisclose : function(record){
        var ca_resp_id = record.id,msgFormContainer = Ext.ComponentQuery.query('#'+this.formContainerId)[0], 
        ticket_id = msgFormContainer.ticket_id,
        opts  = {
            url: '/helpdesk/tickets/get_ca_response_content/'+ticket_id+'?ca_resp_id='+ca_resp_id
        };
        FD.Util.getJSON(opts,this.populateMessage,this);
    },
    config: {
        itemId : 'cannedResponsesPopup',
        cls:'cannedResponses',
        showAnimation: {
                type:'slide',
                direction:'up',
                easing:'ease-out'
        },
        hideAnimation: {
                type:'slide',
                direction:'down',
                easing:'ease-out'
        },
        layout:'fit',
        hidden:true,
        items :[
            {
                    xtype:'list',
                    emptyText: '<div class="empty-list-text">No canned responses available.</div>',
                    onItemDisclosure: false,
                    itemTpl: '<span class="bullet"></span>&nbsp;{title}'
            },
            {
                xtype:'titlebar',
                title:'Canned Responses',
                ui:'header',
                docked:'top',
                items:[
                    {
                        xtype:'button',
                        ui:'plain lightBtn',
                        iconMask:true,
                        align:'left',
                        text:'hide',
                        handler:function(){
                            Ext.ComponentQuery.query('#cannedResponsesPopup')[0].hide();
                        },
                        scope:this
                    },
                    {
                        xtype:'button',
                        ui:'plain headerBtn',
                        iconMask:true,
                        align:'right',
                        text:'apply',
                        handler:function(){
                            var me = Ext.ComponentQuery.query('#cannedResponsesPopup')[0],
                            selection = me.items.items[0].getSelection();
                            if(selection.length) 
                                me.onCannedResDisclose(selection[0].raw)

                        },
                        scope:this
                    }
                ]
            }
        ],
        zIndex:2
    }
});
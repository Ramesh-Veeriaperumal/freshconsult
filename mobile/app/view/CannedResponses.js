Ext.define("Freshdesk.view.CannedResponses", {
    extend: "Ext.Container",
    alias: "widget.cannedResponses",
    onCannedResDisclose : function(list, index, target, record, evt, options){
        var ca_resp_id = record.raw.id,msgFormContainer = Ext.ComponentQuery.query('#'+this.formContainerId)[0], 
        ticket_id = msgFormContainer.ticket_id;
        Ext.Ajax.request({
            url: '/helpdesk/tickets/get_ca_response_content/'+ticket_id+'?ca_resp_id='+ca_resp_id,
            callback: function(req,success,response){
                if(success) {
                        var content = response.responseText,
                        messageElm  = msgFormContainer.getMessageItem();
                        messageElm.setValue(messageElm.getValue()+content);
                        this.hide();
                }
                else {
                        this.hide();
                        Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");   
                }
            },
            scope:this
        });
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
                    itemTpl: '<span class="bullet"></span>&nbsp;{title}',
                    listeners:{
                            itemtap:{
                                fn:function(){
                                    this.parent.onCannedResDisclose.apply(this.parent,arguments);
                                }
                            }
                    }
            },
            {
                xtype:'titlebar',
                title:'Canned Responses',
                ui:'header',
                docked:'top',
                items:[
                    {
                        xtype:'button',
                        ui:'plain headerHtn',
                        iconCls:'delete_black2',
                        iconMask:true,
                        align:'right',
                        handler:function(){
                            Ext.ComponentQuery.query('#cannedResponsesPopup')[0].hide();
                        },
                        scope:this
                    }
                ]
            }
        ],
        zIndex:2
    }
});
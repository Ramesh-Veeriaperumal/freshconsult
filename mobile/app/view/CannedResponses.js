Ext.define("Freshdesk.view.CannedResponses", {
    extend: "Ext.Container",
    alias: "widget.cannedResponses",
    populateMessage : function(res) {
        var content = res.responseText,msgFormContainer = Ext.ComponentQuery.query('#'+this.formContainerId)[0],
        messageElm  = msgFormContainer.getMessageItem();
        messageElm.setValue(messageElm.getValue()+content);
        this.hide();
    },
    getFormatedCannedRes : function(ca_resp_id){
        var msgFormContainer = Ext.ComponentQuery.query('#'+this.formContainerId)[0], 
            ticket_id = msgFormContainer.ticket_id,
            opts  = {
                url: '/helpdesk/tickets/get_ca_response_content/'+ticket_id+'?ca_resp_id='+ca_resp_id
            };
        FD.Util.getJSON(opts,this.populateMessage,this);
    },
    onCannedResDisclose : function(record){
        var self = this,
            showWarning = JSON.parse(FD.Util.cookie.getItem('dontshowcannResWran'));
        if(!showWarning){
            var messageBox = new Ext.MessageBox({
                message: 'Canned responses wraning message.<br/><form><input id="dontshowcannResWranCheck" type="checkbox" name="dontshowagain"> Don\'t show again.</form>',
                modal:true,
                zIndex : 12,
                buttons: [
                    {
                        text:'Ok',
                        handler:function(){
                            var dontshowagain = !!document.getElementById('dontshowcannResWranCheck').checked;
                            FD.Util.cookie.setItem('dontshowcannResWran',dontshowagain,null,'/');
                            messageBox.hide();
                            messageBox.destroy();
                            this.getFormatedCannedRes.apply(self,[record.id]);
                        },
                        scope:self
                    }
                ]
            }).show();
        }
        else{
            this.getFormatedCannedRes.apply(self,[record.id]);
        }
    },
    config: {
        itemId : 'cannedResponsesPopup',
        cls:'cannedResponses',
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
                    emptyText: '<div class="empty-list-text">No canned responses available.</div>',
                    onItemDisclosure: false,
                    itemTpl: '<span class="bullet"></span>&nbsp;{title}'
            },
            {
                xtype:'titlebar',
                title:'Canned Response',
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
                            Ext.ComponentQuery.query('#cannedResponsesPopup')[0].hide();
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
        zIndex:10
    }
});
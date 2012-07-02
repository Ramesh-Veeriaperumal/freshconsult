Ext.define('Freshdesk.view.EmailForm', {
    extend: 'Ext.form.Panel',
    alias: 'widget.emailForm',
    requires: ['Ext.field.Email','Ext.field.Hidden'],
    showCannedResponse : function(){
        var cannedResPopup = Ext.ComponentQuery.query('#cannedResponsesPopup')[0],
        cannedResList = cannedResPopup.items.items[0],
        responses = FD.current_account.canned_responses;
        //setting the data to canned response popup list
        cannedResList.getStore() ? cannedResList.getStore().setData(responses) : cannedResList.setData(responses);
        cannedResPopup.show();
    },
    showSolution: function(){
        var ticket_id = this.parent.ticket_id,solutionsPopup = Ext.ComponentQuery.query('#solutionsPopup')[0];
        Ext.Ajax.request({
            url: 'tickets/get_suggested_solutions/'+ticket_id,
            headers: {
                "Accept": "application/json"
            },
            callback: function(req,success,response){
                if(success){
                        var content = JSON.parse(response.responseText),
                        solutionList = solutionsPopup.items.items[0];
                        if(content.length){
                            solutionList.hideEmptyText();
                            solutionList.getStore() ? solutionList.getStore().setData(content) : solutionList.setData(content);
                        }
                        else {
                            solutionList.showEmptyText();
                        }
                        solutionsPopup.show();
                }
                else{
                        Ext.Msg.alert('Some thing went wrong!', "We are sorry . Some thing went wrong! Our technical team is looking into it.");   
                }
            },
            scope:this
        });
    },
    config: {
        layout:'fit',
        method:'POST',
        url:'/helpdesk/tickets/',
        items : [
            {
                xtype: 'fieldset',
                defaults:{
                        labelWidth:'20%'
                },
                items :[
                    {
                        xtype: 'selectfield',
                        name: 'reply_email[id]',
                        label: 'From :'
                    },
                    {
                        xtype: 'emailfield',
                        name: 'to_email',
                        label: 'To :',
                        readOnly:true
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'include_cc',
                        value:'true'
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'include_bcc',
                        value:'true'
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'helpdesk_note[private]',
                        value:'false'
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'helpdesk_note[source]',
                        value:'0'
                    },
                    {
                        xtype: 'textfield',
                        name: 'cc_emails',
                        label:'Cc/Bcc :',
                        listeners: {
                            focus: function(){
                                this.setLabel('Cc : ');
                                this.parent.items.items[7].setHidden(false);
                            }
                        }
                    },
                    {
                        xtype: 'textfield',
                        name: 'bcc_emails',
                        label:'Bcc :',
                        hidden:true,
                        showAnimation:'fadeIn'
                    },
                    {
                        xtype:'titlebar',
                        ui:'formSubheader',
                        items:[
                            {
                                itemId:'cannedResBtn',
                                xtype:'button',
                                text:'Canned Response',
                                align:'left',
                                ui:'plain',
                                iconMask:true,
                                handler: function(){this.parent.parent.parent.parent.showCannedResponse()},
                                iconCls:'add_black lightPlus'
                            },
                            {
                                itemId:'solutionBtn',
                                xtype:'button',
                                text:'Solution',
                                align:'right',
                                ui:'plain',
                                iconMask:true,
                                iconCls:'add_black lightPlus',
                                handler: function(){this.parent.parent.parent.parent.showSolution()}
                            }
                        ]

                    },
                    {
                        xtype: 'textareafield',
                        name: 'helpdesk_note[body_html]',
                        height: '17em',
                        placeHolder:'Message'
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'commet',
                        value:'Send'
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'email_type',
                        value:'Reply'
                    }
                ]
            }
        ]
    }
});
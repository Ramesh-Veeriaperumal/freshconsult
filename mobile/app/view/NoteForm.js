Ext.define('Freshdesk.view.NoteForm', {
    extend: 'Ext.form.Panel',
    alias: 'widget.noteForm',
    requires: ['Ext.field.Email','Ext.field.Hidden','Ext.field.Checkbox'],
    showCannedResponse : function(){
        var cannedResPopup = Ext.ComponentQuery.query('#cannedResponsesPopup')[0];
        //setting the data to canned response popup list
        cannedResPopup.items.items[0].setData(FD.current_account.canned_responses);
        cannedResPopup.show();
    },
    config: {
        layout:'fit',
        method:'POST',
        url:'/helpdesk/tickets/',
        items : [
            {
                xtype: 'fieldset',
                defaults:{
                        labelWidth:'auto'
                },
                items :[
                    {
                        xtype: 'hiddenfield',
                        name: 'helpdesk_note[source]',
                        value:'2'
                    },
                    {
                        xtype: 'checkboxfield',
                        name: 'helpdesk_note[private]',
                        label:'Private',
                        itemId:'noteFormPrivateField'
                    },
                    {
                        xtype: 'textareafield',
                        name: 'helpdesk_note[body_html]',
                        placeHolder:'Message *',
                        required:true,
                        clearIcon:false
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'commet',
                        value:'Add Note'
                    },
                    {
                        xtype:'titlebar',
                        ui:'formSubheader',
                        itemId:'noteFormCannedResponse',
                        items:[
                            {
                                itemId:'cannedResBtn',
                                xtype:'button',
                                text:'Canned Response',
                                docked:'left',
                                ui:'plain',
                                iconMask:true,
                                handler: function(){this.parent.parent.parent.parent.showCannedResponse()},
                                iconCls:'add_black lightPlus'
                            }
                        ]

                    }
                ]
            }
        ]
    }
});
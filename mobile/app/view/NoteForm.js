Ext.define('Freshdesk.view.NoteForm', {
    extend: 'Ext.form.Panel',
    alias: 'widget.noteForm',
    requires: ['Ext.field.Email','Ext.field.Hidden','Ext.field.Toggle'],
    showCannedResponse : function(){
        var cannedResPopup = Ext.ComponentQuery.query('#cannedResponsesPopup')[0];
        //setting the data to canned response popup list
        cannedResPopup.items.items[0].setData(FD.current_account.canned_responses);
        cannedResPopup.items.items[0].deselectAll();
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
                        xtype: 'textareafield',
                        name: 'helpdesk_note[body_html]',
                        placeHolder:'Enter your note.. *',
                        height:180,
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
                        cls:'green-icon',
                        id:'noteFormCannedResponse',
                        items:[
                            {
                                itemId:'cannedResBtn',
                                xtype:'button',
                                text:'Canned Response',
                                docked:'left',
                                ui:'plain',
                                handler: function(){this.parent.parent.parent.parent.showCannedResponse()}
                            }
                        ],
                        listeners:{
                            initialize: {
                                fn:function(component){
                                    Ext.get('noteFormCannedResponse').on('tap',function(){
                                        this.parent.parent.showCannedResponse();
                                    },component);
                                },
                                scope:this
                            }
                        }

                    },
                    {
                        xtype: 'multiselectfield',
                        name: 'notify_emails',
                        label:'Notify Agents',
                        displayField : 'id', //don't change this property
                        valueField   : 'value', //don't change this property,
                        usePicker : false,
                        store : 'AutoTechnician',
                        itemId: 'noteFormNotifyField',
                        cls:'multiselect'
                    },
                    {
                        xtype: 'togglefield',
                        name: 'helpdesk_note[private]',
                        label: 'Visible to requester ',
                        itemId:'noteFormPrivateField',
                        labelWidth: '71%'
                    },
                ]
            }
        ]
    }
});
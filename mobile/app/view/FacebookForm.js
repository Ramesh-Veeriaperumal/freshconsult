Ext.define('Freshdesk.view.FacebookForm', {
    extend: 'Ext.form.Panel',
    alias: 'widget.facebookForm',
    requires: ['Ext.field.Hidden'],
    config: {
        layout:'fit',
        method:'POST',
        url:'/helpdesk/tickets/',
        items : [
            {
                xtype: 'fieldset',
                defaults:{
                        labelWidth:'25%'
                },
                items :[
                    {
                        xtype: 'textfield',
                        name: 'facebook_handle',
                        label: 'From:',
                        readOnly:true
                    },
                    {
                        xtype: 'textfield',
                        name: 'to_email',
                        label: 'Reply To:',
                        readOnly:true
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'fb_post',
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
                        value:'7'
                    },
                    {
                        xtype: 'textareafield',
                        name: 'helpdesk_note[body]',
                        placeHolder:'Enter your comment *',
                        required:true,
                        clearIcon:false,
                        height:800
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'commet',
                        value:'Send'
                    }
                ]
            }
        ]
    }
});
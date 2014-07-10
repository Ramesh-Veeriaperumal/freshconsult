Ext.define('Freshdesk.view.TweetForm', {
    extend: 'Ext.form.Panel',
    alias: 'widget.tweetForm',
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
                        xtype: 'selectfield',
                        name: 'twitter_handle',
                        label: 'From:'
                    },
                    {
                        xtype: 'textfield',
                        name: 'to_email',
                        label: 'Reply To:',
                        readOnly:true
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'tweet',
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
                        value:'5'
                    },
                    {
                        xtype: 'textareafield',
                        name: 'helpdesk_note[body]',
                        placeHolder:'Enter your message *',
                        maxLength:120,
                        required:true,
                        clearIcon:false
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'commet',
                        value:'Send'
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'tweet_type',
                        value:'mention'
                    }
                ]
            }
        ]
    }
});
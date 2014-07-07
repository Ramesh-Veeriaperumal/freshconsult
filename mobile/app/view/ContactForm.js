Ext.define("Freshdesk.view.ContactForm", {
    extend: "Ext.form.Panel",
    requires: ['Ext.field.Email','Ext.field.Hidden'],
    alias: "widget.contactform",
    config: {
        url:'/contacts/',
        method:'POST',
        standardSubmit:false,
        border:1,
        items:[
            {
                xtype: 'panel',
                tpl:['<div class="customer-info">',
                        '<div class="profile_pic">',
                            '<img src="{avatar}">',
                        '</div>',
                        '<span class="title">{name}</span>',
                        '<br><span>{job_title}</span>',
                      '</div>'].join('')
            },
            {
                xtype: 'fieldset',
                instructions: '* fields are required',
                defaults:{
                    labelWidth:'40%'
                },
                items: [
                    {
                        xtype: 'textfield',
                        name: 'user[name]',
                        label: 'Name',
                        required:true
                    },
                    {
                        xtype: 'emailfield',
                        name: 'user[email]',
                        label: 'Email',
                        required:true
                    },
                    {
                        xtype: 'hiddenfield',
                        name: 'user[helpdesk_agent]',
                        value: false
                    },
                    {
                        xtype: 'textfield',
                        name: 'user[customer]',
                        label: 'Company'
                    },
                    {
                        xtype: 'textfield',
                        name: 'user[job_title]',
                        label: 'Title'
                    },
                    {
                        xtype: 'textfield',
                        name : 'user[phone]',
                        label: 'Work'
                    },
                    {
                        xtype: 'textfield',
                        name : 'user[mobile]',
                        label: 'Mobile'
                    }
                ]
            }
        ]
    }
});
Ext.define("Freshdesk.view.TicketForm", {
    extend: "Ext.form.Panel",
    requires: ['Ext.field.Select','Ext.form.FieldSet','Ext.field.Email','Ext.field.Number'],
    alias: "widget.ticketform",
    config: {
        url:'/helpdesk/tickets/',
        method:'POST',
        border:0,
        items:[
            {
                xtype: 'fieldset',
                scrollable:true,
                itemId:'ticketProperties'
            }
        ]
    }
});
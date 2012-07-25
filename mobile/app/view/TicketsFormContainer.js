Ext.define('Freshdesk.view.TicketsFormContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketsFormContainer',
    initialize: function () {

        this.callParent(arguments);
        var me = this;
        var backButton = {
            text:'Cancel',
            xtype:'button',
            handler:this.backToListView,
            align:'left'
        };

        var submitButton = {
            xtype:'button',
            align:'right',
            text:'Save',
            handler:function(){
                me.items.items[1].submit({
                    success:function(form,response){
                        me.onSaveSuccess(response);
                    }
                });
                
            }
        }

        var topToolbar = {
            xtype: "titlebar",
            docked: "top",
            title:'New Ticket',
            ui:'header',
            items: [
                backButton,
                submitButton
            ]
        };
        var ticketForm = {
            xtype:'ticketform'
        };

        this.add([topToolbar,ticketForm]);
    },
    onSaveSuccess : function(data){
        location.href="#tickets/"+data.record.helpdesk_ticket.display_id
    },
    backToListView: function(){
        Freshdesk.cancelBtn=true;
        history.back();
    },
    config: {
        layout:'fit'
    }
});

Ext.define('Freshdesk.view.NewTicketContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.newTicketContainer',
    initialize: function () {
        this.callParent(arguments);
        var me =this;

        var backButton = {
            xtype:'button',
            text:'List',
			ui:'lightBtn back',
            handler:this.backToViews,
			align:'left'
		};

        var addBtn = Ext.create('Ext.Button',{
            xtype:'button',
            text:'Done',
            align:'right',
            ui:'headerBtn',
            disabled:true,
            handler:this.addTicket,
            id:'NewTicket-addButton'
        });

		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            title: "New Ticket",
            ui:'header',
			items: [backButton,addBtn]
		},
        ticket_fields = {
                xtype: 'ticketform',
                padding:0,
                border:0,
                layout:'fit',
                scrollable:true,
                id:'NewticketProperties'
        };
        this.add([topToolbar,ticket_fields]);
    },
    addTicket : function(){
        //TODO.. validation
        var formContainer = Ext.getCmp('newTicketForm'),
        formObj = formContainer.items.items[1];
        if(FD.Util.validate_form(formObj)){
            formObj.submit({
                success:function(form,response){
                    location.href="#tickets/show/"+response.item.helpdesk_ticket.display_id;
                },
                failure:function(form,response){
                    var errorHtml='Please correct the bellow errors.<br/>';
                    for(var index in response.errors){
                        var error = response.errors[index],eNo= +index+1;
                        errorHtml = errorHtml+'<br/> '+eNo+'.'+error[0]+' '+error[1]
                    }
                    Ext.Msg.alert('Errors', errorHtml, Ext.emptyFn);    
                }
            });    
        }
        else{
            Ext.Msg.alert('', "Please fill all required fields", Ext.emptyFn);
        }
    },
    enableAddBtn : function(){
        Ext.getCmp("NewTicket-addButton").enable();
    },
    disableAddBtn : function(){
        Ext.getCmp("NewTicket-addButton").disable();
    },
    backToViews : function(){
        var anim = {type:'cover',direction:'down'}
        Ext.Viewport.animateActiveItem(Ext.getCmp('filterList'), anim);
    },
    config: {
        layout:'fit',
        scrollable:true,
        cls:'newTicketForm',
        id:'newTicketForm'
    }
});

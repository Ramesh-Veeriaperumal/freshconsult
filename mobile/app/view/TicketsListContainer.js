Ext.define('Freshdesk.view.TicketsListContainer', {
    extend: 'Ext.Container',
    requires:['Ext.TitleBar'],
    alias: 'widget.ticketsListContainer',
    initialize: function () {
        this.callParent(arguments);

        var backButton = {
        	text:'Back',
			ui:'headerBtn back',
			xtype:'button',
			handler:this.backToFilters,
			align:'left'
		};
        

		var topToolbar = {
			xtype: "titlebar",
			docked: "top",
            title:'All Tickets',
            ui:'header',
			items: [
				backButton
			]
		};

		var ticketsList = {
            xtype:'ticketslist',
            store: Ext.getStore('Tickets'),
            listeners:{
                itemtap:{
                    fn:this.onTicketDisclose,
                    scope:this
                }
            },
            plugins: [
                    {
                        xclass: 'Ext.plugin.PullRefresh',
                        pullRefreshText: 'Pull down for more!'
                    },
                    {
                        xclass: 'Ext.plugin.ListPaging',
                        autoPaging: true,
                        centered:true,
                        loadMoreText: '',
                        noMoreRecordsText: ''
                    }
            ]
        };
		this.add([topToolbar,ticketsList]);
    },
    onTicketDisclose: function(list, index, target, record, evt, options){
    	setTimeout(function(){list.deselect(index);},500);
        location.href="#tickets/show/"+record.data.id;
    },
    backToFilters: function(){
        Freshdesk.backBtn=true;
        location.href="#dashboard/tickets";
    },
    setHeaderTitle : function(title){
        this.items.items[0].setTitle(title);
    },
    config: {
        layout:'fit',
        itemId:'ticketListContainer'
    }
});

Ext.define('Freshdesk.controller.Filters', {
    extend: 'Ext.app.Controller',
    slideLeftTransition: { type: 'slide', direction: 'left' },
    slideRightTransition: { type: 'slide', direction: 'right'},
    config:{
        routes:{
            'filters'          : 'loadFilter',
            'filters/:type/:id': 'loadFilter',
        },
    	refs:{
    		// We're going to lookup our views by xtype.
            filtersListContainer: "filtersListContainer",
            ticketsListContainer:"ticketsListContainer",
            contactsListContainer:"contactsListContainer"
    	}
    },
    loadFilter:function(type,id){
        FD.Util.check_user();
        type = type || 'filter';
        id  = id || 'all_tickets';
        Ext.getStore("Tickets").currentPage=1;
        Ext.getStore("Tickets").removeAll();
        url = FD.current_user.is_customer ? '/support/tickets/'+type+'/'+id : '/helpdesk/tickets/'+type+'/'+id ;
        Ext.getStore("Tickets").getProxy()._url=url;
    	Ext.getStore("Tickets").load();
    	var ticketsListContainer = this.getTicketsListContainer(),
        anim = Freshdesk.backBtn ? this.slideRightTransition : Freshdesk.cancelBtn ? {type:'cover',direction:'down'} : this.slideLeftTransition;
		Ext.Viewport.animateActiveItem(ticketsListContainer, anim);
        //setting header for tickets
        ticketsListContainer.setHeaderTitle(this.getFiltersListContainer().filter_title);
        //clearing the previous animations if any
        Freshdesk.backBtn=false;
        Freshdesk.cancelBtn = false;
        ticketsListContainer.filter_type=type;
        ticketsListContainer.filter_id=id;
    },
    launch: function () {
        this.callParent();
    },
    initialize: function () {
        this.callParent();;
    }
});

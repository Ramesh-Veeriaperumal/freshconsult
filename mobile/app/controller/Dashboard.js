Ext.define('Freshdesk.controller.Dashboard', {
    extend: 'Ext.app.Controller',
    slideLeftTransition: { type: 'slide', direction: 'left' },
    slideRightTransition: { type: 'slide', direction: 'right'},
    config:{
        routes:{
            'dashboard'      : 'showItem',
            'dashboard/:name': 'showItem'
        },
    	refs:{
    		// We're going to lookup our views by xtype.
            filtersListContainer: "filtersListContainer",
            contactsListContainer:"contactsListContainer",
            dashboardContainer:"dashboardContainer"

    	}
    },
    showItem:function(name){
        Ext.getStore('Tickets').currentPage=1
        switch (name) {
            case 'tickets'  :
                me =this;
                Ext.getStore('Filters').load();
                var filtersListContainer = this.getFiltersListContainer(),
                anim = Freshdesk.backBtn ? this.slideRightTransition : this.slideLeftTransition;
                Ext.Viewport.animateActiveItem(filtersListContainer, anim);
                break;
            case 'contacts' :
                Ext.getStore("Contacts").loadPage(1);
                var contactsListContainer = this.getContactsListContainer(),
                anim = Freshdesk.backBtn ? this.slideRightTransition : Freshdesk.cancelBtn ? {type:'cover',direction:'down'} :
                this.slideLeftTransition;
                Ext.Viewport.animateActiveItem(contactsListContainer, anim);
                break;
            default :
                me =this;
                Ext.getStore('Filters').load();
                var filtersListContainer = this.getFiltersListContainer(),
                anim = Freshdesk.anim || this.slideRightTransition;
                Ext.Viewport.animateActiveItem(filtersListContainer, anim);
        }
        Freshdesk.anim=undefined;
        Freshdesk.backBtn=false; //TODO . Don't use global objects plz.
        Freshdesk.cancelBtn=false;
    },
    initialize: function () {
        this.callParent();;
    }
});

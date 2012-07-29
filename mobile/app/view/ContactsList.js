Ext.define("Freshdesk.view.ContactsList", {
    extend: "Ext.List",
    alias: "widget.contactslist",
    config: {
        scrollToTopOnRefresh:false,
        indexBar:true,
        grouped:true,
        sorters:'user.name',
        cls:'ticketsList',
        emptyText: '<div class="empty-list-text">You don\'t have any contacts.</div>',
        onItemDisclosure: false,
        loadingText: false,
        itemTpl: [
                '<div class="list-item-title">',
		  		  '<b><div>{user.name}</div></b>',
		  		  '<div class="info_data">{user.email}</div>',
        	  	'</div>'
                        ].join('')

    }
});
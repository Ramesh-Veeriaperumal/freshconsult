Ext.define("Freshdesk.view.FiltersList", {
    extend: "Ext.dataview.List",
    alias: "widget.filterslist",
    config: {
    	cls:'views',
        grouped:true,
        disclosureProperty:'disclosure2',
        emptyText: '<div class="empty-list-text">You don\'t have any views.</div>',
        onItemDisclosure: false,
        itemTpl: ['<tpl if="count &gt; 0"><div class="list-item-title"></tpl><tpl if="count == 0"><div class="list-item-title disabled"></tpl>',
                    '<div class="name">{name}</div>',
        			'<div class="count"><div>{count}</div></div>',
                    '<div class="disclose icon-arrow-right"></div>',
        		   '</div>'].join(''),
        loadingText: false
    }
});

Ext.define("Freshdesk.view.FiltersList", {
    extend: "Ext.dataview.List",
    alias: "widget.filterslist",
    config: {
    	cls:'views',
        grouped:true,
        disclosureProperty:'disclosure2',
        emptyText: '<div class="empty-list-text">You don\'t have any views.</div>',
        onItemDisclosure: false,
        itemTpl: ['<div class="list-item-title">',
                    '<div class="name">{name}</div>',
                    '<div class="disclose icon-arrow-right"></div>',
        		   '</div>'].join(''),
        loadingText: false
    }
});

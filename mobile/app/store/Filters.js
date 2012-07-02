Ext.define('Freshdesk.store.Filters', {
    extend: 'Ext.data.Store',
    config: {
        model: 'Freshdesk.model.Filter',
        proxy: {
            type: 'ajax',
            url : '/mobile/tickets/view_list',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
        autoLoad:true
    }
});

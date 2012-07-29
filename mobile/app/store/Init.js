Ext.define('Freshdesk.store.Init', {
    extend: 'Ext.data.Store',
    config: {
        model: 'Freshdesk.model.Portal',
        proxy: {
            type: 'ajax',
            url : '/mobile/tickets/get_portal',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
        autoLoad:false
    }
});
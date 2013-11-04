Ext.define('Freshdesk.store.Timers', {
    extend: 'Ext.data.Store',
    config: {
        model: 'Freshdesk.model.Timer',
        proxy: {
            type: 'ajax',
            url : '/helpdesk/tickets/',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
    }
});
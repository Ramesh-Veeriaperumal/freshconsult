Ext.define('Freshdesk.store.Filters', {
    extend: 'Ext.data.Store',
    config: {
        model: 'Freshdesk.model.Filter',
        grouper: {
            groupFn: function(record) {
                var company = record.get('company');
                return company || '';
            }
        },
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

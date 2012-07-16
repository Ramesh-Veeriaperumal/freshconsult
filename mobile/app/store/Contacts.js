Ext.define('Freshdesk.store.Contacts', {
    extend: 'Ext.data.Store',
    getTotalCount: function(){
        return this.totalCount;
    },
    config: {
        model: 'Freshdesk.model.Contact',
        sorters: 'user.name',
        grouper:function(record){
            return record.data.user.name.toUpperCase()[0];
        },
        proxy: {
            type: 'ajax',
            url : '/contacts',
            headers: {
                'Accept': 'application/json'
            },
            reader: {
                type: 'json'
            }
        },
        pageSize:50
    }
});
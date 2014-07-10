Ext.define('Freshdesk.model.Filter', {
    extend: 'Ext.data.Model',
    config: {
        idProperty: 'id',
        fields: [
            { name: 'id', type: 'int' },
            { name: 'type', type: 'string'},
            { name: 'name', type: 'string' },
            { name: 'count', type: 'string' },
            { name: 'company', type:'string'}
        ]
    }
});

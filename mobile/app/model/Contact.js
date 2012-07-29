Ext.define('Freshdesk.model.Contact', {
    extend: 'Ext.data.Model',
    config: {
        idProperty: 'id',
        fields: [
            { name: 'user', type: 'object' }
        ]
    }
});
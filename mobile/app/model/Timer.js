Ext.define('Freshdesk.model.Timer', {
    extend: 'Ext.data.Model',
    config: {
        idProperty: 'id',
        fields: [
            { name: 'time_entry', type: 'object'}
        ]
    }
});
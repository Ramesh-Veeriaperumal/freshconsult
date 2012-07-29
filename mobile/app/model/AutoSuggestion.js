Ext.define('Freshdesk.model.AutoSuggestion', {
    extend: 'Ext.data.Model',
    config: {
        idProperty: 'id',
        fields: [
            { name: 'id', type: 'int' },
            { name: 'value', type: 'string'}
        ]
    }
});
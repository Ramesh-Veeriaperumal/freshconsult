Ext.define('Freshdesk.model.Portal', {
    extend: 'Ext.data.Model',
    config: {
        idProperty: 'id',
        fields: [
            { name: 'name', type: 'string' },
            { name: 'logo', type: 'string' },
            { name: 'language', type: 'string' },
            { name:'preferences',type:'Object' }
        ]
    }
});
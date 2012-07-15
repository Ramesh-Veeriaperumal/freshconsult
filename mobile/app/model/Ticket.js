Ext.define('Freshdesk.model.Ticket', {
    extend: 'Ext.data.Model',
    config: {
        idProperty: 'id',
        fields: [
            { name: 'id', type: 'int' },
            { name: 'subject', type: 'string'},
            { name: 'description', type: 'string' },
            { name: 'display_id',type:'string'},
            { name: 'requester_name',type:'string'},
            { name: 'created_at',type:'string'},
            { name: 'updated_at',type:'string'},
            { name: 'responder_name',type:'string'},
            { name: 'status_name',type:'string'},
            { name: 'priority_name',type:'string'},
            { name: 'source',type:'int'},
            { name: 'description_html',type:'string'},
            { name: 'updated_at_in_words',type:'string'},
            { name: 'responder_id', type: 'int' },
            { name : 'need_attention', type:'boolean'},
            { name : 'deleted', type:'boolean'},
            { name : 'spam', type:'boolean'},
            { name : 'conversation_count', type:'int'}
        ]
    }
});
Ext.define("Freshdesk.view.TicketsList", {
    extend: "Ext.dataview.List",
    alias: "widget.ticketslist",
    config: {
        cls:'ticketsList',
        loadingText: false,
        emptyText: '<div class="empty-list-text">You don\'t have any tickets in this view.</div>',
        onItemDisclosure: false,
        itemTpl: Ext.create('Ext.XTemplate',
                ['<tpl for="."><div class="ticket-item {status_name}">',
                        '<tpl if="FD.current_user.is_agent"><div class="{priority_name}">&nbsp;</div><tpl else><div>&nbsp;</div></tpl>',
                        '<div class="title">',
                                '<div><span class="info btn">{status_name}</span></div>',
                                '<div class="subject">',
                                        '<tpl if="need_attention"><span class="need_attention"></span></tpl>',
                                        '{subject}<span class="info">&nbsp;#{display_id}</span>',
                                '</div>',
                                '<div>',
                                        '<tpl if="responder_id">{responder_name},',
                                        '<tpl else>No agent assigned,</tpl>',
                                '&nbsp;{pretty_updated_date}</div>',
                        '</div>',
                        '<div class="disclose icon-arrow-right">&nbsp;</div>',
        	'</div></tpl>'].join(''),
                {
                        time_in_words : function(item){
                            return FD.Util.humaneDate(item);
                        }
                })
    }
});
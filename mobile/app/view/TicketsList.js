Ext.define("Freshdesk.view.TicketsList", {
    extend: "Ext.dataview.List",
    alias: "widget.ticketslist",
    config: {
        cls:'ticketsList',
        loadingText: false,
        emptyText: '<div class="empty-list-text">You don\'t have any tickets in this view.</div>',
        onItemDisclosure: false,
        itemTpl: ['<tpl for="."><div class="ticket-item">',
                        '<tpl if="FD.current_user.is_agent"><div class="{priority_name}">&nbsp;</div></tpl>',
                        '<div class="title">',
                                '<div class="subject">{subject}<span class="info">&nbsp;#{display_id}</span></div>',
                                '<div><span class="info">From: </span>{requester_name}',
                                '<span class="info"> Assigned To: </span>{responder_name}',
                                '</div>',
                                '<div><span class="info btn">{status_name}</span>',
                                '<tpl if="FD.current_user.is_agent"><span class="info btn-light">{priority_name}</span></tpl>',
                                '<span class="info">updated: {updated_at:date("M")} {updated_at:date("d")} , {updated_at:date("h:m A")}</span></div>',
                        '</div>',
                        '<div class="disclose">&nbsp;</div>',
        	'</div></tpl>'].join('')
    }
});
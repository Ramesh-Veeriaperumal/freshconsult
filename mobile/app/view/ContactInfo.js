Ext.define("Freshdesk.view.ContactInfo", {
    extend: "Ext.Container",
    alias: "widget.contactInfo",
    config: {
        itemId:'customerInfo',
        cls:'customerDetails',
        padding:0,
        tpl: Ext.create('Ext.XTemplate',['<tpl if="loading">',
                '<div class="x-mask x-floating" style="background: transparent;min-height:400px"><div class="x-innerhtml">',
                            '<div class="x-loading-spinner" style="font-size: 235%; margin: 100px auto;"><span class="x-loading-top"></span><span class="x-loading-right"></span><span class="x-loading-bottom"></span><span class="x-loading-left"></span></div>',
                '</div></div>',
            '<tpl else>',
            '<div class="customer-info">',
                '<div class="profile_pic">',
                    '<tpl if="avatar_url"><img src="{medium_avatar}"></tpl>',
                    '<tpl if="!avatar_url"><img src="resources/images/profile_blank_thumb.gif"/></tpl>',
                '</div>',
                '<div class="customer-info-list">',
                    '<div class="title">{name}</div>',
                    '<div><tpl if="job_title"> {job_title}</tpl>',
                        '<tpl if="company_name"> <br/> at {company_name}</tpl>',
                    '</div>',
                    '<tpl if="email"><div class="email"><span>&nbsp;</span>{email}</div></tpl>',
                    '<tpl if="mobile"><div class="phone"><span>&nbsp;</span>{mobile}</div></tpl>',
                    '<tpl if="phone"><div class="phone"><span>&nbsp;</span>{phone}</div></tpl>',
                    '<tpl if="twitter_id"><div class="twitter"><span>&nbsp;</span>{twitter_id}</div></tpl>',
                    '<tpl if="fb_profile_id"><div class="facebook"><span>&nbsp;</span>{fb_profile_id}</div></tpl>',
                '</div>',
            '</div>',
            '<div style="clear:both"></div>',
            '<tpl if="recent_tickets"><h3 class="title">Recent 5 tickets</h3>',
            '<div class="ticketsListContainer">',
            '<ul class="ticketsList">',
                '<tpl for="recent_tickets">',
                    '<li>',
                        '<a href="#tickets/show/{helpdesk_ticket.display_id}"><div class="ticket-item {helpdesk_ticket.status_name}">',
                                    '<tpl if="FD.current_user.is_agent"><div class="{helpdesk_ticket.priority_name}">&nbsp;</div><tpl else><div>&nbsp;</div></tpl>',
                                    '<div class="title">',
                                            '<div><span class="info btn">{helpdesk_ticket.status_name}</span></div>',
                                            '<div class="subject">',
                                                    '<tpl if="helpdesk_ticket.need_attention"><span class="need_attention"></span></tpl>',
                                                    '{helpdesk_ticket.subject}<span class="info">&nbsp;#{helpdesk_ticket.display_id}</span>',
                                            '</div>',
                                            '<div>',
                                                    '<tpl if="responder_id">{helpdesk_ticket.responder_name}',
                                                    '<tpl else>No agent assigned, </tpl>',
                                            '&nbsp;{helpdesk_ticket.updated_at:this.time_in_words}</div>',
                                    '</div>',
                                    '<div class="disclose icon-arrow-right">&nbsp;</div>',
                        '</div></a>',
                    '</li>',
                '</tpl>',
            '</ul>',
            '</div>',
            '</tpl>',
            '</tpl>'].join(''),
            {
                time_in_words : function(item){
                    return FD.Util.humaneDate(item);
                }
            })
    }
});
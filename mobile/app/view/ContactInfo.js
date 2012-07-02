Ext.define("Freshdesk.view.ContactInfo", {
    extend: "Ext.Panel",
    alias: "widget.contactInfo",
    config: {
        itemId:'customerInfo',
        tpl:['<h3 class="title">Requester Info</h3>',
            '<div class="customer-info">',
                '<div class="profile_pic">',
                    '<tpl if="avatar_url"><img src="{avatar_url}"></tpl>',
                    '<tpl if="!avatar_url"><img src="resources/images/profile_blank_thumb.gif"/></tpl>',
                '</div>',
                '<span class="title">{name}</span>',
                '<tpl if="job_title"><br><span>{job_title}</span></tpl>',
                '<br><span>{email}</span>',
            '</div>',
            '<tpl if="mobile"><div>{mobile}</div></tpl>',
            '<tpl if="phone"><div>{phone}</div></tpl>',
            '<tpl if="twitter_id"><div>{twitter_id}</div></tpl>',
            '<tpl if="fb_profile_id"><div>{fb_profile_id}</div></tpl>',
            '<span class="seperator"></span>',
            '<tpl if="recent_tickets"><h3 class="title">Recent tickets</h3>',
            '<ul class="ui-list_with_icon">',
                '<tpl for="recent_tickets">',
                    '<li><a href="#tickets/show/{helpdesk_ticket.id}"># {helpdesk_ticket.display_id} {helpdesk_ticket.subject}</a></li>',
                '</tpl>',
            '</ul></tpl>'].join(''),
        padding:0
    }
});
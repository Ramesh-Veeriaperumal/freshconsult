Ext.define("Freshdesk.view.TicketDetails", {
    extend: "Ext.Panel",
    alias: "widget.ticketdetails",
    initialize : function(){
        this.callParent(arguments);
        var tktHeader = {
                id:"details",
                padding:0,
                minWidth:'100%',
                tpl:new Ext.XTemplate(['<div class="HDR">',
                        '<tpl if="!FD.current_user.is_customer">',
                                '<div class="subject">',
                                        '<div class="icon {priority_name} {source_name}"></div>',
                                        '<div class="title">{subject}</div>',
                                '</div>',
                                '<tpl if="!deleted && !spam && !FD.current_user.is_customer"><ul class="actions">',
                                        '<li><a class="chat"       href="#tickets/addNote/{id}">&nbsp;</a></li>',
                                        '<li><a class="automation" href="#tickets/scenarios/{id}">&nbsp;</a></li>',
                                        '<li><a class="reply"      href="#tickets/reply/{id}">&nbsp;</a></li>',
                                        '<li><a class="close"      href="#tickets/resolve/{id}">&nbsp;</a></li>',
                                        '<li><a class="trash"      href="#tickets/delete/{id}">&nbsp;</a></li>',
                                '</ul></tpl>',
                        '</tpl>',
                        '<tpl if="FD.current_user.is_customer">',
                                '<div class="subject"><div class="title full">{subject}</div></div>',
                                '<ul class="actions">',
                                        '<li class="half">Reply <a class="reply"       href="#tickets/addNote/{id}">&nbsp;</a></li>',
                                        '<li class="half"><a class="close"       href="#tickets/close/{id}">&nbsp;</a> Close</li>',
                                '</ul>',
                        '</tpl>',
                      '</div>',
                      '<div class="conversation">',
                        '<div class="thumb">',
                                '<tpl if="requester.avatar_url"><img src="{requester.avatar_url}"/></tpl>',
                                '<tpl if="!requester.avatar_url"><img src="resources/images/profile_blank_thumb.gif"/></tpl>',
                        '</div>',
                        '<div class="Info"><a href="#contacts/show/{requester.id}">{requester.name}</a><br/> on {created_at:date("M")}&nbsp;{created_at:date("d")} @ {created_at:date("h:m A")}</div>',
                        '<div class="msg fromReq">',
                                '<div class="ellipsis" id="{id}">',
                                        '{description_html}',
                                '</div>',
                                '<div id="loadmore_{id}"><tpl if="description_html.length &gt; 200">...<a class="loadMore" href="javascript:FD.Util.showAll({id})"> &middot; &middot; &middot; </a></tpl></div>',
                        '</div>',
                      '</div>',
                      '<tpl for="notes"><div class="conversation">',
                                '<div class="thumb">',
                                        '<tpl if="user.avatar_url"><img src="{user.avatar_url}"/></tpl>',
                                        '<tpl if="!user.avatar_url"><img src="resources/images/profile_blank_thumb.gif"/></tpl>',
                                '</div>',
                                '<div class="Info">',
                                '<tpl if="!FD.current_user.is_customer"><a href="#contacts/show/{user.id}">{user.name}</a></tpl>',
                                '<tpl if="FD.current_user.is_customer"><a href="#">{user.name}</a></tpl>',
                                '<br/> on {created_at:date("M")}&nbsp;{created_at:date("d")} @ {created_at:date("h:m A")}</div>',
                                '<tpl if="parent.requester.id == user_id"><div class="msg fromReq">',
                                        '<div class="ellipsis" id="note_{id}">',
                                                '{body_mobile}',
                                        '</div>',
                                        '<div id="loadmore_note_{id}"><tpl if="body_mobile.length &gt; 200">...<a class="loadMore" href="javascript:FD.Util.showAll(\'note_{id}\')">&middot; &middot; &middot;</a></tpl></div>',
                                '</div></tpl>',
                                '<tpl if="parent.requester.id != user_id"><div class="msg">',
                                        '<div class="ellipsis" id="note_{id}">',
                                                '{body_mobile}',
                                        '</div>',
                                        '<div id="loadmore_note_{id}"><tpl if="body_mobile.length &gt; 200">...<a class="loadMore" href="javascript:FD.Util.showAll(\'note_{id}\')">&middot; &middot; &middot;</a></tpl></div>',
                                '</div></tpl>',
                        '</div></tpl>',
                        '<tpl if="!deleted && !spam && !FD.current_user.is_customer && notes.length &gt; 4"><div class="HDR bottom"><ul class="actions">',
                                '<li><a class="chat"       href="#tickets/addNote/{id}">&nbsp;</a></li>',
                                '<li><a class="automation" href="#tickets/scenarios/{id}">&nbsp;</a></li>',
                                '<li><a class="reply"      href="#tickets/reply/{id}">&nbsp;</a></li>',
                                '<li><a class="close"      href="#tickets/resolve/{id}">&nbsp;</a></li>',
                                '<li><a class="trash"      href="#tickets/delete/{id}">&nbsp;</a></li>',
                        '</ul></tpl></div>',
                ].join(''),{
                        truncate: function(value,length) {
                            return values.substr(0, length);
                        }
                })
        };
        this.add([tktHeader]);
    },
    config: {
        cls:'ticketDetails',
        scrollable: {
            direction: 'vertical'
        }
    }
});
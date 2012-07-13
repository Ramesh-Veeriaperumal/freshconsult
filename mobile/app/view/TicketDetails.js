Ext.define("Freshdesk.view.TicketDetails", {
    extend: "Ext.Panel",
    alias: "widget.ticketdetails",
    initialize : function(){
        this.callParent(arguments);
        var tktHeader = {
                id:"details",
                padding:0,
                minWidth:'100%',
                tpl:new Ext.XTemplate(['<tpl if="loading">',
                        '<div class="x-mask x-floating" style="background: transparent;min-height:400px"><div class="x-innerhtml">',
                            '<div class="x-loading-spinner" style="font-size: 235%; margin: 100px auto;"><span class="x-loading-top"></span><span class="x-loading-right"></span><span class="x-loading-bottom"></span><span class="x-loading-left"></span></div>',
                        '</div></div>',
                        '<tpl else>',
                        '<div class="HDR">',
                        '<tpl if="!FD.current_user.is_customer">',
                                '<div class="subject">',
                                        '<div class="icon {priority_name} {source_name}"></div>',
                                        '<div class="title">{subject}</div>',
                                '</div>',
                                '<tpl if="!deleted && !spam && !FD.current_user.is_customer"><ul class="actions">',
                                        '<li><a class="automation" href="#tickets/scenarios/{id}">&nbsp;</a></li>',
                                        '<li><a class="chat"       href="#tickets/addNote/{id}">&nbsp;</a></li>',
                                        '<li><a class="reply"      href="#tickets/reply/{id}">&nbsp;</a></li>',
                                        '<li><a class="close"      href="#tickets/resolve/{id}">&nbsp;</a></li>',
                                        '<li><a class="trash"      href="#tickets/delete/{id}">&nbsp;</a></li>',
                                '</ul></tpl>',
                        '</tpl>',
                        '<tpl if="FD.current_user.is_customer">',
                                '<div class="subject"><div class="title full">{subject}</div></div>',
                                '<ul class="actions">',
                                        '<li class="half">Reply <a class="reply"       href="#tickets/addNote/{id}">&nbsp;</a></li>',
                                        '<tpl if="!is_closed"><li class="half"><a class="close"       href="#tickets/close/{id}">&nbsp;</a> Close</li></tpl>',
                                '</ul>',
                        '</tpl>',
                      '</div>',
                      '<div class="banner hide" id="notification_msg"></div>',
                      '<tpl if="FD.current_user.is_customer"><div class="banner"><b>{status_name}</b></div></tpl>',
                      '<div class="conversation">',
                        '<div class="thumb">',
                                '<tpl if="requester.avatar_url"><img src="{requester.avatar_url}"/></tpl>',
                                '<tpl if="!requester.avatar_url"><img src="resources/images/profile_blank_thumb.gif"/></tpl>',
                        '</div>',
                        '<div class="Info"><a href="#contacts/show/{requester.id}">{requester.name}</a><br/> on {created_at:date("M")}&nbsp;{created_at:date("d")} @ {created_at:date("h:m A")}</div>',
                        '<div class="msg fromReq">',
                                '<tpl if="attachments.length &gt; 0"><span class="clip">&nbsp;</span></tpl>',
                                '<tpl if="description_html.length &gt; 200"><div class="conv ellipsis" id="{id}"><tpl else>',
                                        '<div class="conv" id="{id}">',
                                '</tpl>',
                                        '{description_html}',
                                '</div>',
                                '<div class="attachments">',
                                        '<tpl for="attachments">',
                                                '<a target="_blank" href="/helpdesk/attachments/{id}"><span>&nbsp;</span><span class="name">{content_file_name:this.fileName}</span>{content_file_name:this.fileType}<span class="size">{content_file_size:this.bytesToSize}</span><span class="disclose">&nbsp;</span></a>',
                                        '</tpl>',
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
                                        '<tpl if="attachments.length &gt; 0"><span class="clip">&nbsp;</span></tpl>',
                                        '<tpl if="body_mobile.length &gt; 200"><div class="conv ellipsis" id="note_{id}"><tpl else><div class="conv" id="note_{id}"></tpl>',
                                                '{body_mobile}',
                                        '</div>',
                                        '<div class="attachments">',
                                                '<tpl for="attachments">',
                                                        '<a target="_blank" href="/helpdesk/attachments/{id}"><span>&nbsp;</span><span class="name">{content_file_name:this.fileName}</span>{content_file_name:this.fileType}<span class="size">{content_file_size:this.bytesToSize}</span><span class="disclose">&nbsp;</span></a>',
                                                '</tpl>',
                                        '</div>',
                                        '<div id="loadmore_note_{id}"><tpl if="body_mobile.length &gt; 200">...<a class="loadMore" href="javascript:FD.Util.showAll(\'note_{id}\')">&middot; &middot; &middot;</a></tpl></div>',
                                '</div></tpl>',
                                '<tpl if="parent.requester.id != user_id"><div class="msg">',
                                        '<tpl if="attachments.length &gt; 0"><span class="clip">&nbsp;</span></tpl>',
                                        '<tpl if="body_mobile.length &gt; 200"><div class="conv ellipsis" id="note_{id}"><tpl else><div class="conv" id="note_{id}"></tpl>',
                                                '{body_mobile}',
                                        '</div>',
                                        '<div class="attachments">',
                                                '<tpl for="attachments">',
                                                        '<a target="_blank" href="/helpdesk/attachments/{id}"><span>&nbsp;</span><span class="name">{content_file_name:this.fileName}</span>{content_file_name:this.fileType}<span class="size">{content_file_size:this.bytesToSize}</span><span class="disclose">&nbsp;</span></a>',
                                                '</tpl>',
                                        '</div>',
                                        '<div id="loadmore_note_{id}"><tpl if="body_mobile.length &gt; 200">...<a class="loadMore" href="javascript:FD.Util.showAll(\'note_{id}\')">&middot; &middot; &middot;</a></tpl></div>',
                                '</div></tpl>',
                        '</div></tpl>',
                        '<tpl if="!deleted && !spam && !FD.current_user.is_customer && notes.length &gt; 4"><div class="HDR bottom"><ul class="actions">',
                                '<li><a class="automation" href="#tickets/scenarios/{id}">&nbsp;</a></li>',
                                '<li><a class="chat"       href="#tickets/addNote/{id}">&nbsp;</a></li>',
                                '<li><a class="reply"      href="#tickets/reply/{id}">&nbsp;</a></li>',
                                '<li><a class="close"      href="#tickets/resolve/{id}">&nbsp;</a></li>',
                                '<li><a class="trash"      href="#tickets/delete/{id}">&nbsp;</a></li>',
                        '</ul></tpl></div></tpl>',
                ].join(''),{
                        truncate: function(value,length) {
                            return values.substr(0, length);
                        },
                        /**
                         * Convert number of bytes into human readable format
                         *
                         * @param integer bytes     Number of bytes to convert
                         * @param integer precision Number of digits after the decimal separator
                         * @return string
                         */
                        bytesToSize : function(bytes, precision) {
                            var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
                            var posttxt = 0;
                            if (bytes == 0) return '0 Bytes';
                            while( bytes >= 1024 ) {
                                posttxt++;
                                bytes = bytes / 1024;
                            }
                            return Number(bytes).toFixed(precision) + " " + sizes[posttxt];
                        },
                        fileName : function(filename){
                            var filename = filename;
                            if(filename && filename.lastIndexOf('.')>0){
                                filename = filename.substr(0,filename.lastIndexOf('.'))
                            }
                            return filename || '';
                        },
                        fileType : function(filename){
                            if(filename && filename.lastIndexOf('.')>0){
                               return filename.substr(filename.lastIndexOf('.'));
                            }
                            return '';
                        }
                })
        };
        this.add([tktHeader]);
    },
    onMessageTap : function(e,item){
      if(item.nodeName === "A"){
        e.stopPropagation();
      }
      else {
        var toggleId = Ext.get(item).hasCls('conv') ? Ext.get(item).id : Ext.get(item).parent('.conv') && Ext.get(item).parent('.conv').id;
        if(toggleId){
            Ext.get(toggleId).toggleCls('ellipsis');
            Ext.get('loadmore_'+toggleId).toggleCls('hide');
        }
      }
    },
    addActionListeners : function(container){
        var elms = container.element.select('.msg').elements,self=this;
        for(var index in elms) {
               Ext.get(elms[index]).on({
                        tap: this.onMessageTap,
                        scope:this
               });
        }
    },
    config: {
        cls:'ticketDetails',
        scrollable: {
            direction: 'vertical'
        }
    }
});
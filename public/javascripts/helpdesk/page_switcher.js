
// options = { pages: ['pageid1', 'pageid2'], cookieName: 'a_cookie_name' }

Helpdesk.PageSwitcher = function(o){
    this.o = o;
    this.addHandlersToLinks();
    if(!o.toggleMode) this.showDefault();
}

Helpdesk.PageSwitcher.prototype = {

    currentPage: '',

    addHandlersToLinks: function(){
        var fn = this.onLinkClick.bind(this);

        this.o.pages.each(function(p){
            var l = $(p + '-link');
            if(l) l.observe('click', fn)
        });
    },

    onLinkClick: function(event){
        var pageId = event.target.id.match(/(.*)-link$/)[1]
        this.show(pageId);

    },
    
    show: function(id){
        if(this.o.onShow) this.o.onShow(id)

        this.o.pages.each(function(p){
            if(p.id != id){
                $(p).hide()
                var l = $(p + '-link');
                if(l) l.removeClassName('active');
            }
        });


        var l = $(id + '-link');

        // There is a bug in prototype causing Element.toggle
        // to not work in an onclick handler. So we do it manually.
        if(this.o.toggleMode && this.currentPage == id){
            this.currentPage = null;
            $(id).hide();
            if(l) l.removeClassName('active');
        }
        else {
            this.currentPage = id;
            if(l) l.addClassName('active');
            $(id).show();
        }

        
        if((!this.o.save || !(this.o.save[id] === false)) && this.o.cookieName)
            Helpdesk.Cookie.set(this.o.cookieName, id, 600);
    },

    showDefault: function(){
        var initial = this.o.cookieName && Helpdesk.Cookie.get(this.o.cookieName);
        this.show(initial || this.o.pages[0]);
    }


}


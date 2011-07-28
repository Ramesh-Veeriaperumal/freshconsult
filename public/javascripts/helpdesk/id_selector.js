Helpdesk.MultiSelector = function(o){
    this.o = o;

    this.monitorCheckboxes();
}

Helpdesk.MultiSelector.prototype = {

    checked: 0,

    monitorCheckboxes: function(){

        this.uncheckAll();

        Event.observe(this.o.form, 'click', this.onClick.bind(this));
        
    },

    onClick: function(event){
        if(Element.hasClassName(event.target, 'selector')){
            this.checked += event.target.checked ? 1 : -1;
            this.showOrHideSelectedToolbar(this.checked);
        }
    },

    showOrHideSelectedToolbar: function(show){
        if(show){
            $('selection-toolbar').show();
            $('toolbar').hide();
        }
        else{
            $('selection-toolbar').hide();
            $('toolbar').show();
        }
    },

    uncheckAll: function(){
        $$('input.selector').each(function(item){
            if(!(item.checked === undefined))
                item.checked = false;
        });

        this.showOrHideSelectedToolbar(false);
        this.checked = 0;
    },

    checkAll: function(){

        this.checked = 0;

        $$('input.selector').each(function(item){
            if(!(item.checked === undefined)){
                item.checked = true;
                this.checked += 1;
            }
        });
    },

    submitOnClick: function(id, params){
        $(id).observe('click', function(event){
            this.submit(
                event.target.readAttribute('action'),
                event.target.readAttribute('method') || 'put',
                params
            );
        }.bind(this));
    },

    // Params is a list of ids for form elements
    // to copy into the form before submission.
    submit: function(url, method, params){

        var form = $(this.o.form);

        if(method)
            form.down('input[name=_method]').value = method;

        (params || []).each(function(p){
            var source = $(p);
            var field = new Element('input', {
                type: 'hidden',
                value: source.value
            });
            field.name = source.name;
            form.appendChild(field);
        });
        form.action = url;
        form.submit();
    }

}



Helpdesk.MultiSelectorsOnPages = function(o){
    this.o = o;
    this.createSwitcher();
    this.createSelectors();
}


Helpdesk.MultiSelectorsOnPages.prototype = {

    createSwitcher: function(){
        this.pageSwitcher = new Helpdesk.PageSwitcher({
            pages: this.o.pages,
            cookieName: this.o.cookieName,
            onShow: this.uncheckAll.bind(this),
            save: this.o.save
        });
    },

    createSelectors: function(){
        this.selectors = {};

        this.o.pages.each(function(p){
            if(!this.o.isSelector || !(this.o.isSelector[p] === false)){
                this.selectors[p] = new Helpdesk.MultiSelector({ form: p });
            }
        }.bind(this));
    },

    checkAll: function(){
        for(p in this.selectors){
            this.selectors[p].checkAll();
        }
    },

    uncheckAll: function(){
        for(p in this.selectors){
            this.selectors[p].uncheckAll();
        }
    },

    submitOnClick: function(id, params){
        $(id).observe('click', function(event){
            this.submit(
                event.target.readAttribute('action'),
                event.target.readAttribute('method') || 'put',
                params
            );
        }.bind(this));
    },

    submit: function(url, method, params){
        this.selectors[this.pageSwitcher.currentPage].submit(url, method, params);
    }
} 

if(!window.Helpdesk) Helpdesk = {};

Helpdesk.ArticleSection = {
    init: function(){
        
        $$(".guide-select input[type=checkbox]").each(function(i){
            i.observe('change', Helpdesk.ArticleSection.onInputChange);
            Helpdesk.ArticleSection.makeHiddenField(i);
        });

    },

    onInputChange: function(e){
        Helpdesk.ArticleSection.makeHiddenField(e.target);
    },

    makeHiddenField: function(checkBox){
        var form = $("article-form");

        if(checkBox.checked){
            var field = new Element('input', {
                type: 'hidden',
                id: checkBox.id + '_hidden',
                value: checkBox.value,
                name: checkBox.name
            });

            form.appendChild(field);
        }
        else {
            var hidden = $(checkBox.id + "_hidden");
            if(hidden) hidden.remove();

        }

    }

}

document.observe("dom:loaded", Helpdesk.ArticleSection.init);

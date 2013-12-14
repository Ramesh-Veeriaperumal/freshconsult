!function ($) {

      "use strict";

      window.ScriptLoader = function(jsAssets,styleAssets)
      {
        this.javascriptAssets = jsAssets; 
        this.stylesheetAssets = styleAssets;
        this.loadingAssets = {};
        this.loadedAssets = {};
      }
      ScriptLoader.prototype = {
        load : function(resource)
        {
          this.get(resource);
        },
        getScript : function(resource,i,type)
        {
          var self = this;
          if(type == true)
          {
            if(window.cloudfront_version == 'development')
            {
              for(var l=0;l<this.stylesheetAssets[resource].length;l++)
              {
                jQuery("<link/>", {
                   rel: "stylesheet",
                   type: "text/css",
                   href: this.stylesheetAssets[resource][l].replace('public/','/')
                }).appendTo("head");
              }
            }
            else
            {
              var url = window.cloudfront_host_url+'/'+resource+'.css';
              jQuery("<link/>", {
                   rel: "stylesheet",
                   type: "text/css",
                   href: url
                }).appendTo("head");
            }   
          }
          else
          {
            if(window.cloudfront_version == 'development')
            {
               jQuery.getScript(this.javascriptAssets[resource][i].replace('public/','/')).done(function(data, textStatus, jqxhr)
              {
                i=i+1;
                // Checking if all resources have been loaded.
                if(i<self.javascriptAssets[resource].length)
                {
                  self.getScript(resource,i,false);
                } 
                else
                {
                  self.loadedAssets[resource] = 1;
                  self.applyLiveQuery(resource);
                }  
              });   
          }
          else
          {
            var url = window.cloudfront_host_url+'/'+resource+'.js';
             jQuery.getScript(url).done(function(data, textStatus, jqxhr)
              {
                  self.loadedAssets[resource] = 1;
                  self.applyLiveQuery(resource); 
              });   
          }
          }
        },
        applyLiveQuery : function(resource)
        {
           if(resource == 'codemirror')
           {
              jQuery('[rel=codemirror]').livequery(function()
                {
                  var options = jQuery(this).data('codemirrorOptions');
                  jQuery(this).codemirror(options);
                })
           }
        },
        get : function(resource)
        {
          if( (typeof this.loadingAssets[resource] == 'undefined'))
          {
            this.loadingAssets[resource] = 1;
            if(typeof this.stylesheetAssets[resource] != 'undefined')
            {
              this.getScript(resource,0,true);
            }
            if(typeof this.javascriptAssets[resource] != 'undefined')
            {
              this.getScript(resource,0,false);
            }
          }  
        } 
      }
    }(window.jQuery);
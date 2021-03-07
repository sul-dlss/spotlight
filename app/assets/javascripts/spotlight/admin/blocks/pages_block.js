//= require spotlight/admin/blocks/resources_block

SirTrevor.Blocks.FeaturedPages = (function(){

  return Spotlight.Block.Resources.extend({
    type: "featured_pages",

    icon_name: "pages",

    autocomplete_url: function() { return $(this.inner).closest('form[data-autocomplete-exhibit-pages-path]').data('autocomplete-exhibit-pages-path').replace("%25QUERY", "%QUERY"); },
    autocomplete_template: function() { return '<div class="autocomplete-item{{#unless published}} blacklight-private{{/unless}}">{{#if thumbnail_image_url}}<div class="document-thumbnail"><img class="img-thumbnail" src="{{thumbnail_image_url}}" /></div>{{/if}}<span class="autocomplete-title">{{title}}</span><br/><small>&nbsp;&nbsp;{{description}}</small></div>' },
    bloodhoundOptions: function() {
      var that = this;
      return {
        prefetch: {
          url: this.autocomplete_url(),
          ttl: 0,
          filter: function(response) {
            // Let the dom know that the response has been returned
            $(that.inner).attr('data-featured_pages-fetched', true);
            return response;
          }
        }
      };
    }
  });

})();

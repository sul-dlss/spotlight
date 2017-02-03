// Module to add multi-image selector to widget panels

(function(){
  $.fn.multiImageSelector = function(image_versions, clickCallback) {
    var changeLink          = $("<a href='javascript:;'>Change</a>"),
        thumbsListContainer = $("<div class='thumbs-list' style='display:none'></div>"),
        thumbList           = $("<ul class='pagination'></ul>"),
        panel;

    var image_ids = $.map(image_versions, function(e) { return e['imageId']; });

    return init(this);

    function init(el) {
      panel = el;
      if(image_versions && image_versions.length > 1) {
        addChangeLink();
        addThumbsList();
      }
    }
    function addChangeLink() {
      $('[data-panel-image-pagination]', panel)
        .html("Image <span data-current-image='true'>" + indexOf(currentThumb()) + "</span> of " + image_versions.length)
        .show()
        .append(" ")
        .append(changeLink);
      addChangeLinkBehavior();
    }
    function currentThumb(){
      return $("[name$='[iiif_image_id]']", panel).attr('value');
    }
    function indexOf(thumb){
      if( (index = image_ids.indexOf(thumb)) > -1 ){
        return index + 1;
      } else {
        return 1;
      }
    }
    function addChangeLinkBehavior() {
      changeLink.on('click', function(){
        thumbsListContainer.slideToggle();
        updateThumbListWidth();
        addScrollBehavior();
        scrollToActiveThumb();
        loadVisibleThumbs();
        swapChangeLinkText($(this));
      });
    }
    function updateThumbListWidth() {
      var width = 0;
      $('li', thumbList).each(function(){
        width += $(this).outerWidth();
      });
      thumbList.width(width + 5);
    }
    function loadVisibleThumbs(){
      var viewportWidth = thumbsListContainer.width();
      var width = 0;
      $('li', thumbList).each(function(){
        var thisThumb  = $(this),
            image      = $('img', thisThumb),
            totalWidth = width += thisThumb.width();
            position   = (thumbList.position().left + totalWidth) - thisThumb.width();

        if(position >= 0 && position < viewportWidth) {
          image.prop('src', image.data('src'));
        }
      });
    }
    function addScrollBehavior(){
      thumbsListContainer.scrollStop(function(){
        loadVisibleThumbs();
      });
    }
    function scrollToActiveThumb(){
      var halfContainerWidth      = (thumbsListContainer.width() / 2),
          activeThumbLeftPosition = ($('.active', thumbList).position() || $('li', thumbList).first().position()).left,
          halfActiveThumbWidth    = ($('.active', thumbList).width() / 2);
      thumbsListContainer.scrollLeft(
        (activeThumbLeftPosition - halfContainerWidth) + halfActiveThumbWidth
      );
    }
    function addThumbsList() {
      addThumbsToList();
      updateActiveThumb();
      $('.panel-heading', panel).append(
        thumbsListContainer.append(
          thumbList
        )
      );
    }
    function updateActiveThumb(){
      $('li', thumbList).each(function(){
        var item = $(this);
        if($('img', item).data('image-id') == currentThumb()){
          item.addClass('active');
        }
      });
    }
    function swapChangeLinkText(link){
      link.text(
        link.text() == 'Change' ? 'Close' : 'Change'
      )
    }
    function addThumbsToList(){
      $.each(image_versions, function(i){
        var listItem = $('<li><a href="javascript:;"><img src="' + image_versions[i]['thumb'] +'" data-image-id="' + image_versions[i]['imageId'] +'" /></a></li>');
        listItem.on('click', function(){
          // get the current image id
          var imageid = $('img', $(this)).data('image-id');
          var src = $('img', $(this)).attr('src');

          // mark the current selection as active
          $('li.active', thumbList).removeClass('active');
          $(this).addClass('active');

          // update the multi-image selector image
          $(".pic.thumbnail img", panel).attr("src", src);

          $('[data-panel-image-pagination] [data-current-image]', panel).text(
            $('li', thumbList).index($(this)) + 1
          );
          scrollToActiveThumb();
          if (typeof clickCallback === 'function' ) {
            clickCallback(image_versions[i]);
          }
        });
        $("img", listItem).on('load', function() {
          updateThumbListWidth();
        });
        thumbList.append(listItem);
      });
    }
  };

})(jQuery);

// source: http://stackoverflow.com/questions/14035083/jquery-bind-event-on-scroll-stops
jQuery.fn.scrollStop = function(callback) {
  $(this).scroll(function() {
    var self  = this,
    $this = $(self);

    if ($this.data('scrollTimeout')) {
      clearTimeout($this.data('scrollTimeout'));
    }

    $this.data('scrollTimeout', setTimeout(callback, 250, self));
  });
};

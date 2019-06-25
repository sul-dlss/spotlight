SirTrevor.Blocks.Wysiwyg = (function() {

  return SirTrevor.Block.extend({
    type: 'wysiwyg',

    icon_name: "text",

    title: function() {
      return i18n.t('blocks:wysiwyg:title');
    },

    description: function() {
      return i18n.t('blocks:wysiwyg:description');
    },

    blockGroup: function() {
      return i18n.t("blocks:group:undefined")
    },

    formattable: true,

    toolbarEnabled: true,

    editorHTML: function() {
      return "<div class='tmce-" + this.blockID + " tinymce'></div>";
    },

    loadData: function(data) {
      this.$("div.tmce-" + this.blockID)[0].innerHTML = data.text;
    },

    onBlockRender: function() {
      var wb = this;
      tinyMCE.init({
        selector: "div.tmce-" + wb.blockID,
        inline: false,
        inline_styles: true,
        menubar: false,
        plugins: [
          'advlist autolink lists link charmap print preview hr anchor pagebreak',
          'searchreplace wordcount visualblocks visualchars code',
          'insertdatetime nonbreaking table contextmenu directionality',
          'paste textcolor colorpicker textpattern codesample'
        ],
        toolbar: 'undo redo | insert | styleselect | bold italic | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | link | forecolor backcolor | table codesample',
        setup: function(editor) {
          editor.on("change", function() {
            wb.blockStorage.data.text = editor.getContent();
          });
        }
      });
    }

  });

})();
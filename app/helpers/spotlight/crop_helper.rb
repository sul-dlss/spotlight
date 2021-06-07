# frozen_string_literal: true

module Spotlight
  ##
  # iiif-crop options helpers
  module CropHelper
    def iiif_cropper_tags(f, initial_crop_selection:)
      tag.div do
        concat f.hidden_field(:iiif_manifest_url)
        concat f.hidden_field(:iiif_canvas_id)
        concat f.hidden_field(:iiif_image_id)
        concat f.hidden_field(:iiif_region)
        concat f.hidden_field(:iiif_tilesource)
        concat iiif_cropper_tag(f, initial_crop_selection: initial_crop_selection)
      end
    end

    def iiif_cropper_tag(f, initial_crop_selection:)
      tag.div('', id: "#{form_prefix(f)}_iiif_cropper", data: {
                behavior: 'iiif-cropper',
                cropper_key: f.object.model_name.singular_route_key,
                'crop-width': initial_crop_selection.first,
                'crop-height': initial_crop_selection.last
              })
    end

    def iiif_upload_tag(f)
      tag.div do
        concat f.file_field_without_bootstrap :file, name: 'featured_image[image]', data: { endpoint: polymorphic_path(f.object.model_name.route_key) }
        concat f.hidden_field :upload_id
      end
    end

    def form_prefix(f)
      f.object_name.parameterize(separator: '_')
    end
  end
end

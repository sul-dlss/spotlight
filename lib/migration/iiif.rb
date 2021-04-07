# frozen_string_literal: true

module Migration
  # This migrates FeaturedImages with crop coordinates into IIIF urls which
  # are stored in the `iiif_url' field.
  class IIIF
    def self.run(hostname)
      new(hostname).run
    end

    def initialize(hostname)
      @hostname = hostname
    end

    def run
      migrate_featured_images
      migrate_contact_avatars
      migrate_upload_images
    end

    attr_reader :hostname

    private

    def riiif
      Riiif::Engine.routes.url_helpers
    end

    def migrate_featured_images
      Spotlight::FeaturedImage.all.each do |image|
        update_iiif_url(image)
        copy_exhibit_thumbnail_from_featured_image(image)
      end
    end

    def migrate_contact_avatars
      Spotlight::Contact.all.each do |contact|
        avatar = copy_contact_image_to_avatar(contact)
        contact.update(avatar: avatar) if avatar
      end
    end

    def migrate_upload_images
      Spotlight::Resources::Upload.all.each do |upload|
        copy_upload_to_featured_image(upload)
      end
    end

    # Checks if the image was associated as a thumbnail.
    # If so, this will update the STI type column of the FeaturedImage as well
    # as copy the file over to the correct directory given the new class name
    def copy_exhibit_thumbnail_from_featured_image(image)
      return unless Spotlight::Exhibit.where(thumbnail_id: image.id).any?

      filename = image.read_attribute_before_type_cast('image')
      filepath = "public/#{image.image.store_dir}/#{filename}"
      image.becomes!(Spotlight::ExhibitThumbnail)
      image.save
      return unless filename.present? && File.exist?(filepath)

      old_file = File.new(filepath)
      # AR + STI seems to require that we re-query for this
      # otherwise we get an association miss-match
      reloaded_image = Spotlight::ExhibitThumbnail.find(image.id)
      reloaded_image.image.store!(old_file)
    end

    # Looks for a file at the old uploader location and copies it to a FeaturedImage
    def copy_contact_image_to_avatar(contact)
      filename = contact.read_attribute_before_type_cast('avatar')
      filepath = "public/uploads/spotlight/contact/avatar/#{contact.id}/#{filename}"
      return unless filename.present? && File.exist?(filepath)

      old_file = File.new(filepath)
      image = contact.create_avatar { |i| i.image.store!(old_file) }
      iiif_tilesource = riiif.info_path(image)
      image.update(iiif_tilesource: iiif_tilesource, iiif_region: avatar_coordinates(contact))
      image
    end

    def copy_upload_to_featured_image(upload)
      return unless upload.exhibit # We need exhibit context to re-index, and you can't find an item not in an exhibit

      filename = upload.read_attribute_before_type_cast('url')
      filepath = "public/uploads/spotlight/resources/upload/url/#{upload.id}/#{filename}"
      return unless filename.present? && File.exist?(filepath)

      old_file = File.new(filepath)
      image = upload.create_upload { |i| i.image.store!(old_file) }
      iiif_tilesource = riiif.info_path(image)
      image.update(iiif_tilesource: iiif_tilesource)
      upload.upload_id = image.id
      upload.save_and_index
    end

    def update_iiif_url(image)
      image.update(
        iiif_tilesource: riiif.info_url(image, host: hostname),
        iiif_region: coordinates(image)
      )
    end

    def coordinates(image)
      return if image.image_crop_x.blank?

      [image.image_crop_x, image.image_crop_y, image.image_crop_w, image.image_crop_h].join(',')
    end

    def avatar_coordinates(contact)
      [contact.avatar_crop_x, contact.avatar_crop_y, contact.avatar_crop_w, contact.avatar_crop_h].join(',')
    end
  end
end

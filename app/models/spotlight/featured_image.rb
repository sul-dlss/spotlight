# frozen_string_literal: true

module Spotlight
  ##
  # Featured images for browse categories, feature pages, and exhibits
  class FeaturedImage < ActiveRecord::Base
    mount_uploader :image, Spotlight::FeaturedImageUploader

    before_validation do
      next unless upload_id.present? && source == 'remote'

      # copy the image from the temp upload
      temp_image = Spotlight::TemporaryImage.find(upload_id)
      self.image = CarrierWave::SanitizedFile.new tempfile: StringIO.new(temp_image.image.read),
                                                  filename: temp_image.image.filename || temp_image.image.identifier,
                                                  content_type: temp_image.image.content_type

      # Unset the incoming iiif_tilesource, which points at the temp image
      self.iiif_tilesource = nil
    end

    after_commit do
      # Clean up the temporary image
      Spotlight::TemporaryImage.find(upload_id).delete if upload_id.present?
    end

    after_save do
      if image.present?
        image.cache! unless image.cached?
        image.store!
      end
    end

    after_save :bust_containing_resource_caches

    attr_accessor :upload_id

    def iiif_url
      return if iiif_service_base.blank?

      [iiif_service_base, iiif_region || 'full', image_size.join(','), '0', 'default.jpg'].join('/')
    end

    # This is used to fetch images given the URL field in the CSV uploads
    # If the image is local, this step will fail, which is okay since the only
    # consumer is CSV uploads and the URL is intended to be remote
    def remote_image_url=(url)
      super url unless url.starts_with? '/'
    end

    def document
      return unless document_global_id && source == 'exhibit'

      @document = nil if @document && document_global_id != @document.to_global_id.to_s

      @document ||= GlobalID::Locator.locate document_global_id
    rescue Blacklight::Exceptions::RecordNotFound => e
      Rails.logger.info("Exception fetching record by id: #{document_global_id}")
      Rails.logger.info(e)

      nil
    end

    def file_present?
      image.file.present?
    end

    def iiif_tilesource
      if self[:iiif_tilesource]
        self[:iiif_tilesource]
      elsif file_present?
        riiif = Riiif::Engine.routes.url_helpers
        riiif.info_path(self)
      end
    end

    # Include a hashed updated_at timestamp in the parameter key to bust any
    # browser caching.
    def to_param
      "#{id}-#{Digest::MD5.hexdigest(updated_at.iso8601)}"
    end

    private

    def image_size
      Spotlight::Engine.config.featured_image_thumb_size
    end

    def iiif_service_base
      iiif_tilesource&.sub('/info.json', '')
    end

    # This is an unfortunate work-around because:
    #   - when this instance is updated through accepts_nested_attributes_for on a parent model,
    #        the parent model is not necessarily updated (to bust caches, etc)
    #   - this model doesn't have an association back to where it is being used
    #   - these images can be used by multiple model instances (e.g. various translations of a feature page)
    #   - this model is used by different types of models (polymorphic use), so belongs_to/has_many doesn't help
    #   - potentially a problem with https://github.com/rails/rails/issues/26726
    #
    # Ideally, we might create a join table to connect this model to where it is used, but 🤷‍♂️
    # Instead, we check each place this might be used and touch it
    def bust_containing_resource_caches
      if Rails.version > '6'
        Spotlight::Search.where(thumbnail: self).or(Spotlight::Search.where(masthead: self)).touch_all
        Spotlight::Page.where(thumbnail: self).touch_all
        Spotlight::Exhibit.where(thumbnail: self).or(Spotlight::Exhibit.where(masthead: self)).touch_all
        Spotlight::Contact.where(avatar: self).touch_all
        Spotlight::Resources::Upload.where(upload: self).touch_all
      else
        bust_containing_resource_caches_rails5
      end
    end

    # Rails 5 doesn't support touch_all.
    def bust_containing_resource_caches_rails5
      Spotlight::Search.where(thumbnail: self).or(Spotlight::Search.where(masthead: self)).find_each(&:touch)
      Spotlight::Page.where(thumbnail: self).find_each(&:touch)
      Spotlight::Exhibit.where(thumbnail: self).or(Spotlight::Exhibit.where(masthead: self)).find_each(&:touch)
      Spotlight::Contact.where(avatar: self).find_each(&:touch)
      Spotlight::Resources::Upload.where(upload: self).find_each(&:touch)
    end
  end
end

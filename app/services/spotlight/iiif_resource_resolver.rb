# frozen_string_literal: true

module Spotlight
  ###
  # Update an ActiveRecord resource that containes identifiers for all the
  # levels of an image resource described in a IIIF manifest
  #
  class IiifResourceResolver
    delegate :iiif_manifest_url, :iiif_canvas_id, :iiif_image_id, to: :resource
    def initialize(resource)
      @resource = resource
    end

    def resolve!
      resource.iiif_tilesource = updated_tilesource
      return resource.save if resource.changed?

      Rails.logger.info("#{self.class.name} resolved #{iiif_manifest_url}, but nothing changed.")
    end

    private

    attr_reader :resource

    def updated_tilesource
      "#{updated_image['resource']['service']['@id']}/info.json"
    end

    def updated_image
      new_image = updated_canvas['images'].find do |image|
        image['@id'] == iiif_image_id
      end

      raise(ManifestError, "No image with @id #{iiif_image_id} found in #{iiif_manifest_url}") unless new_image

      new_image
    end

    def updated_canvas
      new_canvas = canvases.find do |canvas|
        canvas['@id'] == iiif_canvas_id
      end

      raise(ManifestError, "No canvas with @id #{iiif_canvas_id} found in #{iiif_manifest_url}") unless new_canvas

      new_canvas
    end

    def canvases
      sequence['canvases'] || []
    end

    # Currently only supporting a single sequence
    def sequence
      Array.wrap(manifest['sequences']).first || {}
    end

    def response
      @response ||= begin
        Spotlight::Resources::IiifService.http_client.get(iiif_manifest_url).body
      rescue Faraday::Error => e
        Rails.logger.warn("#{self.class.name} failed to fetch #{iiif_manifest_url} with: #{e}")
        '{}'
      end
    end

    def manifest
      @manifest ||= begin
        JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.warn("#{self.class.name} failed to parse #{iiif_manifest_url} with: #{e}")
        {}
      end
    end

    class ManifestError < RuntimeError; end
  end
end

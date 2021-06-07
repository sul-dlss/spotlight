# frozen_string_literal: true

module Spotlight
  ##
  # Proxy update requests to Solr and inject spotlight's exhibit
  # specific fields.
  #
  # This is an example of how you could integrate external indexing
  # workflows with exhibit-specific content
  class SolrController < Spotlight::ApplicationController
    include Spotlight::SearchHelper
    before_action :authenticate_user!
    before_action :validate_writable_index!

    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    delegate :blacklight_config, to: :current_exhibit

    def update
      authorize! :update_solr, @exhibit

      data = solr_documents

      repository.connection.update params: { commitWithin: 500 }, data: data.to_json, headers: { 'Content-Type' => 'application/json' } unless data.empty?

      if params[:resources_json_upload]
        redirect_back fallback_location: exhibit_resources_path(@exhibit)
      else
        head :ok
      end
    end

    private

    def solr_documents
      req = ActiveSupport::JSON.decode(json_content)

      Array.wrap(req).map do |r|
        custom_field_data = r.dup.extract! @exhibit.custom_fields.pluck(:slug)
        other_field_data = r.except(custom_field_data.keys)

        doc = blacklight_config.document_model.new(other_field_data)

        create_or_update_solr_document_sidecar(doc, r)

        doc.to_solr.merge(@exhibit.solr_data).merge(other_field_data)
      end
    end

    def json_content
      if params[:resources_json_upload]
        params[:resources_json_upload][:json].read
      else
        request.body.read
      end
    end

    def validate_writable_index!
      return if Spotlight::Engine.config.writable_index

      render plain: 'Spotlight is unable to write to solr', status: :conflict
    end

    def create_or_update_solr_document_sidecar(doc, data)
      return if data.blank?

      sidecar = doc.sidecar(@exhibit)
      sidecar.data = sidecar.data.merge(data)
      sidecar.save

      sidecar
    end
  end
end

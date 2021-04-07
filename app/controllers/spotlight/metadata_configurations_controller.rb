# frozen_string_literal: true

module Spotlight
  ##
  # CRUD actions for Blacklight metadata fields (e.g. index/show fields for
  # various view types)
  class MetadataConfigurationsController < Spotlight::ApplicationController
    before_action :authenticate_user!
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    load_and_authorize_resource :blacklight_configuration, through: :exhibit, singleton: true, parent: false

    def show
      respond_to do |format|
        format.json do
          render json: @blacklight_configuration.blacklight_config.index_fields.as_json
        end
      end
    end

    def edit
      add_breadcrumb t(:'spotlight.exhibits.breadcrumb', title: @exhibit.title), @exhibit
      add_breadcrumb t(:'spotlight.configuration.sidebar.header'), exhibit_dashboard_path(@exhibit)
      add_breadcrumb t(:'spotlight.configuration.sidebar.metadata'), edit_exhibit_metadata_configuration_path(@exhibit)
    end

    def update
      if @blacklight_configuration.update(exhibit_params)
        flash[:notice] = t(:'helpers.submit.blacklight_configuration.updated', model: @blacklight_configuration.class.model_name.human.downcase)
        redirect_to edit_exhibit_metadata_configuration_path(@exhibit)
      else
        render action: 'edit'
      end
    end

    private

    def exhibit_params
      params.require(:blacklight_configuration).permit(
        index_fields: [exhibit_configuration_index_params]
      )
    end

    def exhibit_configuration_index_params
      views = @blacklight_configuration.default_blacklight_config.view.keys | [:show]

      @blacklight_configuration.blacklight_config.index_fields.keys.index_with do |_element|
        (%i[enabled label weight] | views)
      end
    end
  end
end

# frozen_string_literal: true

module Spotlight
  ##
  # CRUD actions for Blacklight search configuration
  class SearchConfigurationsController < Spotlight::ApplicationController
    include Spotlight::SearchHelper

    before_action :authenticate_user!
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    load_and_authorize_resource :blacklight_configuration, through: :exhibit, singleton: true, parent: false

    def show
      respond_to do |format|
        format.json do
          render json: @blacklight_configuration.default_blacklight_config.view.to_h.reject { |_k, v| v.if == false }.keys
        end
      end
    end

    def edit
      add_breadcrumb t(:'spotlight.exhibits.breadcrumb', title: @exhibit.title), @exhibit
      add_breadcrumb t(:'spotlight.configuration.sidebar.header'), exhibit_dashboard_path(@exhibit)
      add_breadcrumb t(:'spotlight.configuration.sidebar.search_configuration'), edit_exhibit_search_configuration_path(@exhibit)

      @field_metadata = Spotlight::FieldMetadata.new(current_exhibit, blacklight_config.repository, @blacklight_configuration.blacklight_config)
    end

    def update
      if @blacklight_configuration.update(exhibit_params)
        flash[:notice] = t(:'helpers.submit.blacklight_configuration.updated', model: @blacklight_configuration.class.model_name.human.downcase)
        redirect_to edit_exhibit_search_configuration_path(@exhibit)
      else
        render action: 'edit'
      end
    end

    private

    def exhibit_params
      params.require(:blacklight_configuration).permit(
        :default_per_page,
        facet_fields: [exhibit_configuration_facet_params],
        search_fields: [exhibit_configuration_search_params],
        sort_fields: [exhibit_configuration_sort_params],
        document_index_view_types: @blacklight_configuration.default_blacklight_config.view.keys
      )
    end

    def exhibit_configuration_facet_params
      @blacklight_configuration.blacklight_config.facet_fields.keys.index_with do |_element|
        %i[show label weight sort]
      end
    end

    def exhibit_configuration_search_params
      @blacklight_configuration.blacklight_config.search_fields.keys.index_with do |_element|
        %i[enabled label weight]
      end
    end

    def exhibit_configuration_sort_params
      @blacklight_configuration.blacklight_config.sort_fields.keys.index_with do |_element|
        %i[enabled label weight]
      end
    end
  end
end

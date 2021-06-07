# frozen_string_literal: true

module Spotlight
  ##
  # Base CRUD controller for translations
  class TranslationsController < Spotlight::ApplicationController
    before_action :authenticate_user!, :set_language, :set_tab
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit

    def edit
      attach_breadcrumbs
    end

    def update
      if current_exhibit.update(exhibit_params)
        I18n.reload! # reload since we're memoizing
        notice = t(:'helpers.submit.spotlight_default.updated', model: current_exhibit.class.model_name.human.downcase)
        redirect_to edit_exhibit_translations_path(current_exhibit, language: @language, tab: @tab), notice: notice
      else
        render 'edit'
      end
    end

    def show
      respond_to do |format|
        format.yaml
      end
    end

    def import
      if current_exhibit.update(import_exhibit_params)
        I18n.reload! # reload since we're memoizing
        notice = t(:'helpers.submit.spotlight_default.updated', model: current_exhibit.class.model_name.human.downcase)
        redirect_to edit_exhibit_translations_path(current_exhibit, language: @language), notice: notice
      else
        render 'edit'
      end
    end

    private

    def attach_breadcrumbs
      add_breadcrumb t(:'spotlight.exhibits.breadcrumb', title: @exhibit.title), @exhibit
      add_breadcrumb t(:'spotlight.curation.sidebar.header'), exhibit_dashboard_path(@exhibit)
      add_breadcrumb t(:'spotlight.curation.sidebar.translations')
    end

    def exhibit_params
      params.require(:exhibit).permit(translations_attributes: %i[id locale key value])
    end

    def import_exhibit_params
      imported_translations = YAML.safe_load(params.require(:file).read)

      # set language from YML root locale
      language = imported_translations.keys.first

      # convert YML to hash
      translation = unfold(imported_translations.values.first).map do |k, v|
        current_translation = Translation.find_or_initialize_by(exhibit: current_exhibit, key: k, locale: language)
        { key: k, value: v, locale: language, id: current_translation.id }
      end

      { translations_attributes: translation }
    end

    def set_language
      @language = params[:language] || current_exhibit.available_locales.first
    end

    def set_tab
      @tab = params[:tab]
    end

    def unfold(value, key = nil, &block)
      return to_enum(:unfold, value, key) unless block_given?

      if value.is_a? Hash
        value.each do |k, v|
          arr = unfold(v, [key, k].compact.join('.'))
          arr.each(&block)
        end
      else
        yield key, value
      end
    end
  end
end

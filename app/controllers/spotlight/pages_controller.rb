# frozen_string_literal: true

module Spotlight
  ##
  # Base CRUD controller for pages
  # rubocop:disable Metrics/ClassLength
  # Disableing class length because this is a base
  # controller that gives other controllers their behavior
  class PagesController < Spotlight::ApplicationController
    before_action :authenticate_user!, except: [:show]
    before_action :load_locale_specific_page, only: %i[destroy edit show update]
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    load_and_authorize_resource through: :exhibit, instance_name: 'page', only: [:index]

    helper Openseadragon::OpenseadragonHelper
    include Spotlight::SearchHelper
    include Spotlight::Base
    include Blacklight::SearchContext

    helper_method :get_search_results, :search_results, :fetch, :page_collection_name

    before_action do
      blacklight_config.action_mapping.default = blacklight_config.index
      blacklight_config.action_mapping.show = blacklight_config.index
      blacklight_config.view.gallery.classes = 'row-cols-2 row-cols-md-4' unless @page&.display_sidebar
    end

    # GET /exhibits/1/pages
    def index
      # set up a model the inline "add a new page" form
      @page = CanCan::ControllerResource.new(self).send(:build_resource)

      respond_to do |format|
        format.html
        format.json { render json: @pages.for_locale.published.to_json(methods: [:thumbnail_image_url]) }
      end
    end

    # GET /pages/1
    def show
      fresh_when([@page.exhibit, @page, request.query_parameters.to_query])
    end

    def preview
      @page = current_exhibit.pages.find(params['id'])
      authorize! :read, @page
      @block = SirTrevorRails::Block.from_hash(JSON.parse(params[:block], symbolize_names: true), @page)

      respond_to do |format|
        format.html { render 'preview', layout: false }
      end
    end

    # GET /exhibits/1/pages/new
    def new; end

    # GET /pages/1/edit
    def edit
      @page.lock! current_user
    end

    # POST /exhibits/1/pages
    def create
      @page.attributes = page_params
      @page.last_edited_by = @page.created_by = current_user

      if @page.save
        redirect_to [spotlight, @page.exhibit, page_collection_name.to_sym],
                    notice: t(:'helpers.submit.page.created', model: @page.class.model_name.human.downcase)
      else
        render action: 'new'
      end
    end

    # PATCH/PUT /pages/1
    def update
      @page.lock&.delete

      if @page.update(page_params.merge(last_edited_by: current_user))
        redirect_to [spotlight, @page.exhibit, @page, { format: params.permit(:format) }], flash: { html_safe: true }, notice: undo_notice(:updated)
      else
        render action: 'edit'
      end
    end

    # DELETE /pages/1
    def destroy
      @page.destroy

      redirect_to [spotlight, @page.exhibit, page_collection_name.to_sym], flash: { html_safe: true }, notice: undo_notice(:destroyed)
    end

    def update_all
      notice = if @exhibit.update update_all_page_params
                 t(:'helpers.submit.page.batch_updated', model: human_name)
               else
                 t(:'helpers.submit.page.batch_error', model: human_name)
               end
      redirect_back fallback_location: spotlight.exhibit_dashboard_path(@exhibit), notice: notice
    end

    def clone
      new_page = CloneTranslatedPageFromLocale.call(locale: clone_params, page: @page)

      model_name = @page.class.model_name.human.downcase
      if new_page.save
        redirect_to(
          edit_exhibit_translations_path(current_exhibit, language: clone_params, tab: 'pages'),
          notice: t(:'helpers.submit.page.created', model: model_name)
        )
      else
        redirect_to :back, error: t(:'helpers.submit.page.clone_error', model: model_name)
      end
    end

    protected

    def _prefixes
      @_prefixes ||= super + ['catalog']
    end

    # Add a Page specific search_results method that takes user params as
    # an option and passes that off to the search service to get results
    # @param [Hash] the query parameters
    # @return [Object] the search results object from the configured search service
    def search_results(user_params)
      search_service(user_params).search_results
    end

    def undo_link
      return unless can? :manage, @page
      return if @page.versions.blank?

      view_context.link_to(t(:'spotlight.versions.undo'), revert_version_path(@page.versions.last), method: :post)
    end

    def undo_notice(key)
      view_context.safe_join([t(:"helpers.submit.page.#{key}", model: @page.class.model_name.human.downcase), undo_link], ' ')
    end

    def clone_params
      params.require(:language)
    end

    ##
    # Browsing an exhibit should start a new search session
    def start_new_search_session?
      params[:action] == 'show'
    end

    def page_attributes
      %i[id published title weight display_sidebar parent_page_id]
    end

    def allowed_page_params
      [:title, :content, { thumbnail_attributes: featured_image_params }]
    end

    def human_name
      @human_name ||= page_collection_name.humanize
    end

    alias page_collection_name controller_name

    def attach_breadcrumbs
      if view_context.current_page? '/'
        add_breadcrumb t(:'spotlight.curation.nav.home', title: current_exhibit.title), main_app.root_path
      elsif @page
        # Use curator-accessible i18n key for user-facing breadcrumb
        breadcrumb_to_exhibit_root(:'spotlight.curation.nav.home')
      else
        # Use admin interface language for dashboard breadcrumb
        breadcrumb_to_exhibit_root(:'spotlight.exhibits.breadcrumb')
      end
    end

    def load_locale_specific_page
      @page = current_exhibit.pages.for_locale.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_page_to_related_locale_version
    end

    private

    def update_all_page_params
      params.require(:exhibit).permit(
        pages_attributes: %i[id published]
      )
    end

    def breadcrumb_to_exhibit_root(key)
      add_breadcrumb t(key, title: current_exhibit.title), spotlight.exhibit_root_path(current_exhibit)
    end

    # Only allow a trusted parameter "white list" through.
    def page_params
      params.require(controller_name.singularize).permit(allowed_page_params)
    end

    def redirect_page_to_related_locale_version
      pages_for_id = current_exhibit.pages.find(params[:id])
      if pages_for_id.default_locale_page
        redirect_to polymorphic_path([current_exhibit, pages_for_id.default_locale_page])
      elsif pages_for_id.translated_page_for(I18n.locale)
        redirect_to polymorphic_path([current_exhibit, pages_for_id.translated_page_for(I18n.locale)])
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end

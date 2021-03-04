# frozen_string_literal: true

describe Spotlight::BulkActionsController, type: :controller do
  routes { Spotlight::Engine.routes }
  let(:exhibit) { FactoryBot.create(:skinny_exhibit) }

  describe 'when the user is not authorized' do
    before do
      sign_in FactoryBot.create(:exhibit_visitor)
    end

    describe 'POST change_visibility' do
      it 'denies access' do
        post :change_visibility, params: { exhibit_id: exhibit }
        expect(response).to redirect_to main_app.root_path
        expect(flash[:alert]).to be_present
      end
    end

    describe 'POST add_tags' do
      it 'denies access' do
        post :add_tags, params: { exhibit_id: exhibit }
        expect(response).to redirect_to main_app.root_path
        expect(flash[:alert]).to be_present
      end
    end

    describe 'POST remove_tags' do
      it 'denies access' do
        post :remove_tags, params: { exhibit_id: exhibit }
        expect(response).to redirect_to main_app.root_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'when the user is a curator' do
    before do
      sign_in FactoryBot.create(:exhibit_curator, exhibit: exhibit)
    end

    let(:search) { FactoryBot.create(:search, exhibit: exhibit) }
    let(:search_session) { instance_double('Blacklight::Search', query_params: { q: 'map' }) }

    describe 'POST change_visibility' do
      it 'redirects and sets a notice' do
        allow(controller).to receive(:current_search_session).and_return(search_session)
        request.env['HTTP_REFERER'] = '/referring_url'
        post :change_visibility, params: { 'visibility' => 'private', 'q' => 'map', exhibit_id: exhibit }
        expect(response).to redirect_to '/referring_url'
        expect(flash[:notice]).to eq 'Visibility of 55 items is being updated.'
      end

      # rubocop:disable Style/MultilineBlockChain
      it 'enqueues the job' do
        allow(controller).to receive(:current_search_session).and_return(search_session)
        expect do
          post :change_visibility, params: { 'visibility' => 'private', 'q' => 'map', exhibit_id: exhibit }
        end.to have_enqueued_job(Spotlight::ChangeVisibilityJob).with do |solr_params, exhb, visibility|
          expect(solr_params).to.not be_nil
          expect(exhb).to eq exhibit
          expect(visibility).to eq 'private'
        end
      end
      # rubocop:enable Style/MultilineBlockChain
    end

    describe 'POST add_tags' do
      it 'redirects and sets a notice' do
        allow(controller).to receive(:current_search_session).and_return(search_session)
        request.env['HTTP_REFERER'] = '/referring_url'
        post :add_tags, params: { 'tags' => 'howdy,planet', 'q' => 'map', exhibit_id: exhibit }
        expect(response).to redirect_to '/referring_url'
        expect(flash[:notice]).to eq 'Tags are being added for 55 items.'
      end

      # rubocop:disable Style/MultilineBlockChain
      it 'enqueues the job' do
        allow(controller).to receive(:current_search_session).and_return(search_session)
        expect do
          post :add_tags, params: { 'tags' => 'howdy,planet', 'q' => 'map', exhibit_id: exhibit }
        end.to have_enqueued_job(Spotlight::AddTagsJob).with do |solr_params, exhb, tags|
          expect(solr_params).to.not be_nil
          expect(exhb).to eq exhibit
          expect(tags).to eq %w[howdy planet]
        end
      end
      # rubocop:enable Style/MultilineBlockChain
    end

    describe 'POST remove_tags' do
      it 'redirects and sets a notice' do
        allow(controller).to receive(:current_search_session).and_return(search_session)
        request.env['HTTP_REFERER'] = '/referring_url'
        post :remove_tags, params: { 'tags' => 'hello,world', 'q' => 'map', exhibit_id: exhibit }
        expect(response).to redirect_to '/referring_url'
        expect(flash[:notice]).to eq 'Tags are being removed for 55 items.'
      end

      # rubocop:disable Style/MultilineBlockChain
      it 'enqueues the job' do
        allow(controller).to receive(:current_search_session).and_return(search_session)
        expect do
          post :remove_tags, params: { 'tags' => 'howdy,planet', 'q' => 'map', exhibit_id: exhibit }
        end.to have_enqueued_job(Spotlight::RemoveTagsJob).with do |solr_params, exhb, tags|
          expect(solr_params).to.not be_nil
          expect(exhb).to eq exhibit
          expect(tags).to eq %w[howdy planet]
        end
      end
      # rubocop:enable Style/MultilineBlockChain
    end
  end
end

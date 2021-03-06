# frozen_string_literal: true

RSpec.describe 'Catalog controller', type: :routing do
  describe 'routing' do
    routes { Spotlight::Engine.routes }

    it 'routes to #show with a format' do
      expect(get('/1/catalog/dq287tq6352.xml')).to route_to('spotlight/catalog#show', exhibit_id: '1', id: 'dq287tq6352', format: 'xml')
    end

    it 'routes to #edit' do
      expect(get('/1/catalog/dq287tq6352/edit')).to route_to('spotlight/catalog#edit', exhibit_id: '1', id: 'dq287tq6352')
    end

    it 'routes to #manifest' do
      expect(get('/1/catalog/1-1/manifest.json')).to route_to('spotlight/catalog#manifest', exhibit_id: '1', id: '1-1', format: 'json')
    end

    context 'when the routing constraint is set to allow periods' do
      before do
        allow(Spotlight::Engine.config.routes).to receive(:solr_documents).and_return(constraints: { id: %r{[^/]+} })
        Rails.application.reload_routes!
      end

      after do
        Rails.application.reload_routes!
      end

      it 'routes to #show as expected' do
        expect(get('/1/catalog/gallica.bnf.fr')).to route_to('spotlight/catalog#show', exhibit_id: '1', id: 'gallica.bnf.fr')
      end
    end
  end
end

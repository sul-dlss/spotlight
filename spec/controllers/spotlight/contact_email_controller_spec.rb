# frozen_string_literal: true

describe Spotlight::ContactEmailController, type: :controller do
  routes { Spotlight::Engine.routes }
  let(:contact_email) { FactoryBot.create(:contact_email) }

  context 'when not logged in' do
    describe 'DELETE destroy' do
      it 'redirects to the login page' do
        # NOTE: about odd behavior: it was discovered in testing that if format: :json is explicitly specified here, the user is redirected
        # to login on rails 4, but gets a 401 on rails 5.  we suspect differing CanCan behavior, but didn't investigate in depth.
        delete :destroy, params: { id: contact_email, exhibit_id: contact_email.exhibit }
        # custom logic in ApplicationController redirects user to app login page on CanCan::AccessDenied if user can't read current exhibit
        expect(response).to redirect_to main_app.new_user_session_path
      end
    end
  end

  context 'when logged in' do
    before { sign_in user }

    context 'as a visitor' do
      let(:user) { FactoryBot.create(:exhibit_visitor) }

      describe 'DELETE destroy' do
        it 'redirects to the home page' do
          delete :destroy, params: { id: contact_email, exhibit_id: contact_email.exhibit }
          # custom logic in ApplicationController redirects user to app root on CanCan::AccessDenied if user's allowed to view current exhibit
          expect(response).to redirect_to main_app.root_path
        end
      end
    end

    context 'as an exhibit curator' do
      let(:user) { FactoryBot.create(:exhibit_curator, exhibit: contact_email.exhibit) }

      describe 'DELETE destroy' do
        it 'redirects to the home page' do
          delete :destroy, params: { id: contact_email, exhibit_id: contact_email.exhibit }
          # custom logic in ApplicationController redirects user to app root on CanCan::AccessDenied if user's allowed to view current exhibit
          expect(response).to redirect_to main_app.root_path
        end
      end
    end

    context 'as an exhibit admin' do
      let(:user) { FactoryBot.create(:exhibit_admin, exhibit: contact_email.exhibit) }

      describe 'DELETE destroy' do
        it 'is successful when the record exists' do
          delete :destroy, params: { id: contact_email, exhibit_id: contact_email.exhibit }
          expect(response).to be_successful
          expect(JSON.parse(response.body)).to eq('success' => true, 'error' => nil)
        end

        it 'gives a 404 with appropriate message when the record no longer exists' do
          contact_email.destroy
          delete :destroy, params: { id: contact_email, exhibit_id: contact_email.exhibit }
          expect(response.status).to eq 404
          expect(JSON.parse(response.body)).to eq('success' => false, 'error' => 'Not Found')
        end
      end
    end
  end
end

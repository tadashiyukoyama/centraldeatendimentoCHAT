require 'rails_helper'

RSpec.describe EmailUnsubscriptionsController, type: :request do
  let(:contact) { create(:contact, email: 'customer@example.com') }
  let(:token) { Email::UnsubscribeTokenService.generate(contact) }

  it 'shows a neutral confirmation page for a valid token' do
    get "/email/unsubscribe/#{token}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Cancelar recebimento')
  end

  it 'renders the confirmation page in English when requested' do
    get "/email/unsubscribe/#{token}", params: { lang: 'en' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Unsubscribe from email')
  end

  it 'records the unsubscribe decision' do
    post "/email/unsubscribe/#{token}"

    expect(response).to have_http_status(:ok)
    expect(contact.reload.additional_attributes['email_unsubscribed']).to be(true)
    expect(contact.additional_attributes['email_unsubscribed_at']).to be_present
  end

  it 'returns not found for an invalid token' do
    get '/email/unsubscribe/invalid'

    expect(response).to have_http_status(:not_found)
  end
end

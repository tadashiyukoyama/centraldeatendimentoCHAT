require 'rails_helper'

RSpec.describe 'AceleraChat legal and privacy requests', type: :request do
  let(:facts) do
    {
      LEGAL_ENTITY_NAME: 'Acelera Serviços Ltda.',
      LEGAL_ENTITY_CNPJ: '00.000.000/0001-00',
      LEGAL_ENTITY_ADDRESS: 'Rua Exemplo, 100, São Paulo/SP',
      LEGAL_DPO_NAME: 'Encarregado Exemplo',
      PRIVACY_CONTACT_EMAIL: 'privacidade@meugerenciador.pro',
      SUPPORT_CONTACT_EMAIL: 'suporte@meugerenciador.pro',
      ACELERACHAT_PUBLIC_CONTENT_AUTHOR_EMAIL: 'author@example.com',
      FRONTEND_URL: 'https://atendimento.meugerenciador.pro'
    }
  end

  it 'renders stable Portuguese and English legal routes' do
    with_modified_env facts do
      get '/legal/terms'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Termos de Uso', 'Acelera Serviços Ltda.')

      get '/legal/privacy', params: { lang: 'en' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Privacy and LGPD')
    end
  end

  it 'returns 503 instead of publishing an incomplete legal draft' do
    with_modified_env facts.merge(LEGAL_ENTITY_ADDRESS: '') do
      get '/legal/terms'
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).not_to include('{{LEGAL_ENTITY_ADDRESS}}')
    end
  end

  it 'publishes legal pages without a registration label when CNPJ is absent' do
    with_modified_env facts.merge(LEGAL_ENTITY_CNPJ: '') do
      get '/legal/terms'

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('CNPJ')
      expect(response.body).not_to include('{{LEGAL_ENTITY_CNPJ}}')
    end
  end

  it 'creates a neutral request and sends a branded verification email' do
    with_modified_env facts do
      expect do
        post '/legal/data-request', params: {
          privacy_request: { email: 'titular@example.com', request_type: 'access', details: 'Solicitação de acesso' }
        }
      end.to change(PrivacyRequest, :count).by(1).and change(ActionMailer::Base.deliveries, :count).by(1)

      expect(response).to have_http_status(:accepted)
      expect(response.body).to include('resposta neutra')
      expect(ActionMailer::Base.deliveries.last.subject).to include('AceleraChat')
    end
  end

  it 'accepts the response field posted by the hCaptcha widget' do
    captcha = instance_double(ChatwootCaptcha, valid?: true)
    allow(ChatwootCaptcha).to receive(:new).with('widget-token').and_return(captcha)

    with_modified_env facts do
      post '/legal/data-request', params: {
        'h-captcha-response' => 'widget-token',
        :privacy_request => { email: 'titular@example.com', request_type: 'access' }
      }
    end

    expect(response).to have_http_status(:accepted)
    expect(ChatwootCaptcha).to have_received(:new).with('widget-token')
  end

  it 'returns a validation response for an unsupported request type' do
    with_modified_env facts do
      expect do
        post '/legal/data-request', params: {
          privacy_request: { email: 'titular@example.com', request_type: 'unknown' }
        }
      end.not_to change(PrivacyRequest, :count)
    end

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'keeps the public response neutral when email delivery fails' do
    allow(PrivacyRequestMailer).to receive(:with).and_raise(Net::SMTPFatalError.new('mailbox unavailable'))

    with_modified_env facts do
      post '/legal/data-request', params: {
        privacy_request: { email: 'titular@example.com', request_type: 'access' }
      }
    end

    expect(response).to have_http_status(:accepted)
    expect(PrivacyRequest.last.events.pluck(:event_type)).to include('verification_email_failed')
    expect(response.body).not_to include('mailbox unavailable')
  end

  it 'verifies and protects status lookup with separate tokens', :aggregate_failures do
    request_record = PrivacyRequest.new(email: 'titular@example.com', request_type: :deletion).prepare_submission!
    verification_token = request_record.raw_verification_token
    status_token = request_record.raw_status_token
    request_record.save!

    with_modified_env facts do
      post legal_data_request_confirm_path(request_protocol: request_record.protocol), params: { token: verification_token }
      expect(response).to have_http_status(:ok)
      expect(request_record.reload).to be_status_verified

      get legal_data_request_status_path(request_protocol: request_record.protocol), params: { token: 'wrong' }
      expect(response).to have_http_status(:not_found)

      get legal_data_request_status_path(request_protocol: request_record.protocol), params: { token: status_token }
      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
      expect(response.headers['X-Robots-Tag']).to include('noindex')
      expect(response.body).to include(request_record.protocol)
      expect(response.body).not_to include(request_record.email)
    end
  end
end

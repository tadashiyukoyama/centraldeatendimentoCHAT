/* global axios */
import ApiClient from '../ApiClient';

class WhatsappChannel extends ApiClient {
  constructor() {
    super('whatsapp', { accountScoped: true });
  }

  createEmbeddedSignup(params) {
    return axios.post(`${this.baseUrl()}/whatsapp/authorization`, params);
  }

  reauthorizeWhatsApp({ inboxId, ...params }) {
    return axios.post(`${this.baseUrl()}/whatsapp/authorization`, {
      ...params,
      inbox_id: inboxId,
    });
  }

  createEvolutionProvisioning(params) {
    return axios.post(
      `${this.baseUrl()}/whatsapp/evolution_provisionings`,
      params
    );
  }

  getEvolutionProvisioning(publicId) {
    return axios.get(
      `${this.baseUrl()}/whatsapp/evolution_provisionings/${publicId}`
    );
  }

  reconnectEvolutionProvisioning(publicId) {
    return axios.post(
      `${this.baseUrl()}/whatsapp/evolution_provisionings/${publicId}/reconnect`
    );
  }

  disconnectEvolutionProvisioning(publicId) {
    return axios.post(
      `${this.baseUrl()}/whatsapp/evolution_provisionings/${publicId}/disconnect`
    );
  }

  deleteEvolutionProvisioning(publicId) {
    return axios.delete(
      `${this.baseUrl()}/whatsapp/evolution_provisionings/${publicId}`
    );
  }
}

export default new WhatsappChannel();

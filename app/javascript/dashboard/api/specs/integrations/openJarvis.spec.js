import OpenJarvisAPI from '../../integrations/openJarvis';
import ApiClient from '../../ApiClient';

describe('#OpenJarvisAPI', () => {
  it('exposes the native connection operations', () => {
    expect(OpenJarvisAPI).toBeInstanceOf(ApiClient);
    expect(OpenJarvisAPI).toHaveProperty('update');
    expect(OpenJarvisAPI).toHaveProperty('rotateAccessToken');
    expect(OpenJarvisAPI).toHaveProperty('rotateWebhookSecret');
    expect(OpenJarvisAPI).toHaveProperty('testConnection');
    expect(OpenJarvisAPI).toHaveProperty('getDeliveries');
    expect(OpenJarvisAPI).toHaveProperty('disconnect');
  });
});

Rails.application.config.to_prepare do
  PublicBrand.reset!
  PublicBrand.validate!
end

module PublicBrandI18nBackend
  def translate(locale, key, options = {})
    PublicBrand.public_text(super)
  end
end

I18n.backend.singleton_class.prepend(PublicBrandI18nBackend) unless I18n.backend.singleton_class < PublicBrandI18nBackend

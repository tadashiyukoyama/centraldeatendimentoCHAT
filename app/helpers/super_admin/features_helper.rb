module SuperAdmin::FeaturesHelper
  def self.available_features
    features = YAML.load(ERB.new(Rails.root.join('app/helpers/super_admin/features.yml').read).result).with_indifferent_access
    return features unless PublicBrand.active?

    features.each_value do |attributes|
      attributes[:name] = public_text(attributes[:name])
      attributes[:description] = public_text(attributes[:description])
    end
    features
  end

  def self.plan_details
    plan = PublicBrand.value('PUBLIC_PLAN_NAME', ChatwootHub.pricing_plan)
    quantity = ChatwootHub.pricing_plan_quantity

    if plan == 'premium'
      "You are currently on the <span class='font-semibold'>#{plan}</span> plan with <span class='font-semibold'>#{quantity} agents</span>."
    else
      "You are currently on the <span class='font-semibold'>#{plan}</span> edition plan."
    end
  end

  def self.public_text(value)
    value.to_s.gsub(/Chatwoot/i, 'AceleraChat').gsub(/Captain|Capitão/i, 'Nemmo').gsub(/Enterprise/i, 'PRO')
  end
  private_class_method :public_text
end

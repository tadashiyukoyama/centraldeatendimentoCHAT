module PrivacyRequestLabels
  extend ActiveSupport::Concern

  SUPPORTED_LOCALES = %w[pt_BR en].freeze
  STATUS_LABELS = {
    'pt_BR' => {
      'pending_verification' => 'Aguardando verificação',
      'verified' => 'Verificada',
      'in_review' => 'Em análise',
      'completed' => 'Concluída',
      'rejected' => 'Rejeitada'
    },
    'en' => {
      'pending_verification' => 'Pending verification',
      'verified' => 'Verified',
      'in_review' => 'In review',
      'completed' => 'Completed',
      'rejected' => 'Rejected'
    }
  }.freeze
  REQUEST_TYPE_LABELS = {
    'pt_BR' => {
      'access' => 'Acesso',
      'correction' => 'Correção',
      'portability' => 'Portabilidade',
      'deletion' => 'Exclusão',
      'objection' => 'Oposição',
      'consent_withdrawal' => 'Revogação do consentimento'
    },
    'en' => {
      'access' => 'Access',
      'correction' => 'Correction',
      'portability' => 'Portability',
      'deletion' => 'Deletion',
      'objection' => 'Objection',
      'consent_withdrawal' => 'Consent withdrawal'
    }
  }.freeze

  included do
    validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  end

  def status_label(display_locale = locale)
    STATUS_LABELS.fetch(supported_display_locale(display_locale)).fetch(status)
  end

  def request_type_label(display_locale = locale)
    REQUEST_TYPE_LABELS.fetch(supported_display_locale(display_locale)).fetch(request_type)
  end

  private

  def supported_display_locale(display_locale)
    candidate = display_locale.to_s
    SUPPORTED_LOCALES.include?(candidate) ? candidate : 'pt_BR'
  end
end

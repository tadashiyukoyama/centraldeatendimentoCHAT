# frozen_string_literal: true

# Curate the PDF-derived knowledge for the production Captain assistant.
# Records that describe unverified, internal, mobile-only, or future/custom
# capabilities remain pending and are therefore excluded from FAQ retrieval.
#
# Run with:
#   CAPTAIN_ACCOUNT_ID=1 CAPTAIN_DOCUMENT_ID=2 bundle exec rails runner scripts/revise_captain_knowledge_base.rb

account = Account.find(Integer(ENV.fetch('CAPTAIN_ACCOUNT_ID')))
assistant = account.captain_assistants.order(:id).first or raise 'Captain assistant not found'
document_id = Integer(ENV.fetch('CAPTAIN_DOCUMENT_ID'))

# FAQ answers are prose; keep each answer as one persisted string.
# rubocop:disable Layout/LineLength
approved = {
  4 => {
    question: 'O que é o AI Food Manager?',
    answer: 'O AI Food Manager é uma plataforma para centralizar atendimento, reservas, mesas, fila, clientes, eventos, conteúdo do site e automações de canais em uma operação única para negócios de alimentação.'
  },
  5 => {
    question: 'Quais são as principais funcionalidades do AI Food Manager?',
    answer: 'A solução pode incluir painel web, mapa de mesas, reservas e fila de espera, central multicanal com IA e transferência para atendimento humano, além de integrações com WhatsApp/Meta, Instagram, Telegram e chat do site. O que fica ativo depende do plano, da configuração e da validação de cada canal; aplicativo móvel e automações específicas precisam ser confirmados no onboarding.'
  },
  6 => {
    question: 'Como o AI Food Manager melhora a operação de um restaurante?',
    answer: 'Ele centraliza canais como WhatsApp, Instagram e site, organiza reservas, mesas e filas em uma interface única e mantém o histórico para a equipe. Assim, o negócio reduz perda de contexto e pode atender o cliente no canal que ele já utiliza.'
  },
  7 => {
    question: 'Como funciona o mapa de mesas no painel do AI Food Manager?',
    answer: 'Quando o módulo está configurado, o mapa permite criar o salão, cadastrar mesas com capacidade e formato, posicioná-las e acompanhar estados como disponível, ocupada ou bloqueada. Recursos como juntar e separar mesas dependem das regras e permissões da implantação.'
  },
  8 => {
    question: 'Quais regras podem ser aplicadas às reservas?',
    answer: 'O módulo de reservas pode aplicar horários de funcionamento, dias fechados, antecedência mínima, datas bloqueadas, capacidade do salão e prevenção de conflitos de horário ou mesa. As regras exatas são definidas no onboarding e não devem ser presumidas sem consultar a configuração do negócio.'
  },
  9 => {
    question: 'Como funciona a central de atendimento do AI Food Manager?',
    answer: 'A central reúne conversas dos canais configurados, como WhatsApp, Instagram e chat do site, e permite respostas manuais ou automáticas, notas internas, etiquetas, prioridades e transferência para o responsável ou setor adequado. A disponibilidade de cada canal depende da integração e da validação externa.'
  },
  11 => {
    question: 'Como o Instagram pode ser integrado ao sistema?',
    answer: 'O Instagram pode ser integrado pela API da Meta para receber e enviar mensagens diretas e centralizar o histórico. Campanhas de comentários para DM dependem da configuração da conta, das permissões e das políticas da Meta; devem ser validadas antes de serem prometidas ao cliente.'
  },
  12 => {
    question: 'Como funciona a contratação e a implantação do AI Food Manager?',
    answer: 'A contratação começa pela definição do plano e dos módulos necessários. Depois são feitos configuração, integração dos canais, testes, personalização das regras e onboarding. O número e as contas da Meta podem ser novos ou existentes, mas precisam atender às validações e políticas da Meta.'
  },
  15 => {
    question: 'Como funciona a central de atendimento multicanal?',
    answer: 'As conversas dos canais configurados ficam agrupadas com histórico, status, responsáveis, etiquetas e notas internas. A equipe pode responder, alterar o status e transferir a conversa para outro responsável ou setor. O comportamento de cada canal depende de sua integração e janela de mensagens.'
  },
  16 => {
    question: 'Quais setores de atendimento estão configurados atualmente?',
    answer: 'Nesta implantação estão configurados financeiro, contas a pagar, RH, gerência, representante e suporte, além da transferência para o responsável principal. O Captain só deve transferir para um setor quando o cliente pedir esse setor ou quando houver um sinal explícito que justifique a transferência.'
  },
  17 => {
    question: 'Como funciona o chat do site?',
    answer: 'Quando o widget está instalado e o domínio está validado, o chat do site pode manter a sessão, registrar o histórico e encaminhar a conversa para a central. As respostas e os fluxos disponíveis dependem da configuração do site e das integrações ativas.'
  },
  18 => {
    question: 'Quais são as opções para integrar o chat ao site?',
    answer: 'O chat pode ser inserido em um site novo ou em um site existente por meio do widget configurado para o domínio. A implantação pode incluir personalização visual, tom de voz, regras de negócio e links para canais como WhatsApp, Instagram, mapas, reservas e cardápio, conforme o escopo contratado.'
  },
  19 => {
    question: 'Como funciona a automação de comentários do Instagram para envio de DM?',
    answer: 'Quando habilitada e aprovada pela Meta, uma campanha pode observar comentários que correspondam a palavras-chave e iniciar uma DM ou uma conversa no Instagram. A campanha precisa respeitar as permissões, limites e políticas da Meta, e deve ser testada com a conta e a publicação corretas.'
  },
  21 => {
    question: 'O que é necessário para configurar o WhatsApp Meta?',
    answer: 'A integração normalmente exige número elegível, Phone Number ID, WhatsApp Business Account ID, token de acesso, webhook, verify token e segredo do aplicativo. Os valores devem ser obtidos no painel da Meta e mantidos em segredo; também é necessário testar recebimento, envio, janela de atendimento e templates aprovados.'
  },
  23 => {
    question: 'Como o Telegram pode ser utilizado pelo gerente?',
    answer: 'Quando o bot está configurado, o Telegram pode servir como canal executivo para avisos, tarefas, conteúdo, agenda e relatórios, com comandos e menus guiados. O conjunto de ações depende das permissões e dos módulos efetivamente implantados.'
  },
  24 => {
    question: 'Quais funções administrativas podem ser oferecidas pelo Telegram?',
    answer: 'Dependendo da implantação, o gerente pode revisar conteúdo, acompanhar alertas e tarefas, consultar informações e usar fluxos guiados com confirmação antes de alterações. Não se deve assumir que toda função está ativa sem verificar o bot e as permissões do ambiente.'
  },
  27 => {
    question: 'O que pode estar incluído na contratação do AI Food Manager?',
    answer: 'O plano pode incluir módulos de atendimento e operação definidos no onboarding, configuração, integrações, testes, orientação e suporte. Meta WhatsApp, Instagram, chat do site, automações e personalizações dependem do escopo contratado, da aprovação das plataformas externas e da validação de cada canal.'
  },
  28 => {
    question: 'Como funciona a ativação de um número Meta?',
    answer: 'Pode ser usado um número Meta novo ou um número existente, conforme a elegibilidade e a validação da Meta. A ativação envolve a conta comercial, Phone Number ID, token, webhook e aprovações do cliente. A posse do número e os requisitos comerciais continuam vinculados à conta do cliente e às políticas da Meta.'
  },
  30 => {
    question: 'Que tipos de personalização podem ser avaliados?',
    answer: 'Podem ser avaliados horários e regras por unidade ou evento, setores e responsáveis, tom de voz e prompts, campos adicionais, automações de campanhas e integrações externas. Cada item precisa ser confirmado tecnicamente e incluído no escopo antes de ser apresentado como disponível.'
  }
}.freeze
# rubocop:enable Layout/LineLength

responses = assistant.responses.where(documentable_type: 'Captain::Document', documentable_id: document_id).index_by(&:id)
missing = approved.keys - responses.keys
raise "FAQ IDs not found: #{missing.join(', ')}" if missing.any?

ActiveRecord::Base.transaction do
  responses.each_value do |response|
    revision = approved[response.id]
    if revision
      response.update!(question: revision[:question], answer: revision[:answer], status: :approved)
    else
      response.update!(status: :pending)
    end
  end
end

puts({
  account_id: account.id,
  assistant_id: assistant.id,
  document_id: document_id,
  approved_ids: approved.keys,
  approved_count: approved.length,
  pending_count: responses.length - approved.length
}.to_json)

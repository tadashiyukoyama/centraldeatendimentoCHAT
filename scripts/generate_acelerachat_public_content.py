#!/usr/bin/env python3
"""Generate the versioned AceleraChat help and legal Markdown package."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "config/acelerachat/public_content"

HELP_ARTICLES = [
    ("agent_bots", "automation", "agentes-virtuais", "Agentes virtuais", "agent-bots-en", "Agent bots", "Configure automações que atendem e transferem conversas com supervisão humana."),
    ("agents", "administration", "usuarios-papeis-e-permissoes", "Usuários, papéis e permissões", "users-roles-and-permissions-en", "Users, roles, and permissions", "Defina administradores, gerentes e agentes segundo o menor privilégio necessário."),
    ("audit_logs", "security", "logs-de-auditoria", "Logs de auditoria", "audit-logs-en", "Audit logs", "Acompanhe alterações administrativas e eventos relevantes sem registrar segredos."),
    ("campaigns", "operations", "campanhas", "Campanhas", "campaigns-en", "Campaigns", "Crie comunicações segmentadas respeitando consentimento, opt-out e políticas dos canais."),
    ("canned_responses", "operations", "respostas-prontas", "Respostas prontas", "canned-responses-en", "Canned responses", "Padronize respostas frequentes sem perder a revisão do agente."),
    ("channel_email", "channels", "canal-de-email", "Canal de e-mail", "email-channel-en", "Email channel", "Conecte uma caixa de e-mail, valide remetente e teste recebimento e resposta."),
    ("channel_facebook", "channels", "canal-do-facebook", "Canal do Facebook", "facebook-channel-en", "Facebook channel", "Conecte páginas autorizadas e respeite as políticas e janelas definidas pela Meta."),
    ("custom_attributes", "administration", "atributos-personalizados", "Atributos personalizados", "custom-attributes-en", "Custom attributes", "Estruture dados de contatos e conversas com finalidade e acesso definidos."),
    ("dashboard_apps", "integrations", "aplicativos-de-dashboard", "Aplicativos de dashboard", "dashboard-apps-en", "Dashboard apps", "Incorpore ferramentas internas somente por HTTPS e com origem confiável."),
    ("help_center", "administration", "central-de-ajuda", "Central de Ajuda", "help-center-en", "Help Center", "Publique documentação por idioma e mantenha artigos revisados e acessíveis."),
    ("inboxes", "channels", "caixas-de-entrada-e-setores", "Caixas de entrada, WhatsApp QR e setores", "inboxes-and-teams-en", "Inboxes, WhatsApp QR, and teams", "Conecte canais, atribua setores e opere o mesmo número com fronteiras de acesso."),
    ("integrations", "integrations", "integracoes", "Integrações", "integrations-en", "Integrations", "Ative apenas integrações próprias, valide credenciais e limite o escopo dos tokens."),
    ("labels", "operations", "etiquetas", "Etiquetas", "labels-en", "Labels", "Classifique conversas e contatos com uma taxonomia pequena e consistente."),
    ("macros", "automation", "macros-e-automacoes", "Macros e automações", "macros-and-automations-en", "Macros and automations", "Automatize passos repetitivos mantendo condições, responsáveis e rollback claros."),
    ("reports", "operations", "relatorios", "Relatórios", "reports-en", "Reports", "Acompanhe volume, tempo de resposta e desempenho sem ampliar acesso a conversas."),
    ("sla", "operations", "suporte-e-sla", "Suporte e SLA", "support-and-sla-en", "Support and SLA", "Entenda prioridades, horários de atendimento e canais de suporte AceleraChat."),
    ("team_management", "security", "setores-e-privacidade", "Setores, hierarquia e privacidade rígida", "teams-and-privacy-en", "Teams, hierarchy, and strict privacy", "Separe conversas por setor no mesmo número e preserve visibilidade administrativa autorizada."),
    ("webhook", "integrations", "webhooks-e-api", "Webhooks e API", "webhooks-and-api-en", "Webhooks and API", "Integre sistemas por HTTPS, autenticação, idempotência e registros sem dados sensíveis."),
    ("billing", "commercial", "planos-e-cobranca", "Planos e cobrança", "plans-and-billing-en", "Plans and billing", "Consulte os recursos PRO; cobrança recorrente permanece indisponível nesta entrega."),
    ("saml", "security", "login-sso-saml", "Login SSO/SAML", "sso-saml-login-en", "SSO/SAML login", "Centralize autenticação corporativa sem remover o acesso de recuperação dos administradores."),
    ("captain", "nemmo", "nemmo-visao-geral", "Nemmo: visão geral", "nemmo-overview-en", "Nemmo overview", "Crie assistentes, bases, FAQ e ferramentas com transferência segura para humanos."),
    ("captain_billing", "nemmo", "nemmo-creditos-e-limites", "Nemmo: créditos e limites", "nemmo-credits-and-limits-en", "Nemmo credits and limits", "Monitore consumo, limites e indisponibilidade sem expor chaves de provedores."),
]

CATEGORIES = {
    "administration": ("Administração", "Administration"),
    "automation": ("Automação", "Automation"),
    "channels": ("Canais", "Channels"),
    "commercial": ("Comercial", "Commercial"),
    "integrations": ("Integrações", "Integrations"),
    "nemmo": ("Nemmo", "Nemmo"),
    "operations": ("Operação", "Operations"),
    "security": ("Segurança e privacidade", "Security and privacy"),
}

LEGAL_ARTICLES = [
    ("terms", "termos-de-uso", "Termos de Uso", "terms-of-use-en", "Terms of Use", "terms", "Regras de acesso, uso aceitável, disponibilidade, suspensão e responsabilidades."),
    ("privacy", "privacidade-e-lgpd", "Privacidade e LGPD", "privacy-and-lgpd-en", "Privacy and LGPD", "privacy", "Como dados pessoais são tratados e como o titular exerce seus direitos."),
    ("cookies", "politica-de-cookies", "Política de Cookies", "cookie-policy-en", "Cookie Policy", "cookies", "Cookies essenciais e controles para tecnologias opcionais."),
    ("data_request", "solicitacoes-de-titulares", "Solicitações de titulares", "data-subject-requests-en", "Data Subject Requests", "data_request", "Confirmação, acesso, correção, portabilidade, oposição e exclusão."),
    ("account_deletion", "exclusao-de-conta", "Exclusão de conta", "account-deletion-en", "Account deletion", None, "Encerramento da conta empresarial e efeitos sobre dados e backups."),
    ("retention", "retencao-e-backups", "Retenção e backups", "retention-and-backups-en", "Retention and backups", None, "Critérios de retenção, descarte e cópias de segurança."),
    ("dpa", "acordo-de-tratamento-de-dados", "Acordo de Tratamento de Dados", "data-processing-agreement-en", "Data Processing Agreement", None, "Responsabilidades entre controlador cliente e operador AceleraChat."),
    ("subprocessors", "subprocessadores", "Subprocessadores", "subprocessors-en", "Subprocessors", None, "Categorias de fornecedores e dever de atualização da lista operacional."),
    ("security", "seguranca-e-vulnerabilidades", "Segurança e vulnerabilidades", "security-and-vulnerabilities-en", "Security and vulnerabilities", None, "Práticas de segurança e canal de divulgação responsável."),
    ("incidents", "incidentes-de-seguranca", "Incidentes de segurança", "security-incidents-en", "Security incidents", None, "Detecção, contenção e comunicação de incidentes relevantes."),
    ("acceptable_use", "uso-aceitavel", "Uso aceitável", "acceptable-use-en", "Acceptable Use", None, "Proibições contra abuso, fraude, spam e violação de terceiros."),
    ("billing_policy", "assinatura-cancelamento-e-reembolso", "Assinatura, cancelamento e reembolso", "subscription-cancellation-refund-en", "Subscription, cancellation, and refunds", None, "Regras comerciais que serão ativadas junto da futura cobrança própria."),
    ("support_sla", "sla-e-suporte", "SLA e suporte", "support-and-sla-policy-en", "Support and SLA", None, "Canais, severidades e metas de atendimento."),
    ("ai_transparency", "transparencia-do-nemmo", "Transparência do Nemmo", "nemmo-transparency-en", "Nemmo transparency", None, "Uso de IA, supervisão humana, provedores e limites."),
    ("third_party_channels", "canais-de-terceiros", "Canais de terceiros", "third-party-channels-en", "Third-party channels", None, "Responsabilidades ao integrar WhatsApp, Meta e outros provedores."),
    ("open_source", "software-livre-e-terceiros", "Software livre e terceiros", "open-source-and-third-party-notices-en", "Open source and third-party notices", None, "Preservação de licenças e atribuições obrigatórias."),
]

HELP_SUMMARIES_EN = {
    "agent_bots": "Configure automations that answer and transfer conversations with human oversight.",
    "agents": "Assign administrators, managers, and agents according to least privilege.",
    "audit_logs": "Review administrative changes and relevant events without recording secrets.",
    "campaigns": "Create segmented communications while respecting consent, opt-out, and channel policies.",
    "canned_responses": "Standardize frequent replies while preserving agent review.",
    "channel_email": "Connect an email inbox, validate the sender, and test receipt and reply.",
    "channel_facebook": "Connect authorized pages and follow Meta policies and messaging windows.",
    "custom_attributes": "Structure contact and conversation data with a defined purpose and access scope.",
    "dashboard_apps": "Embed internal tools only over HTTPS and from trusted origins.",
    "help_center": "Publish accessible documentation by language and keep articles reviewed.",
    "inboxes": "Connect channels, assign teams, and operate one number with clear access boundaries.",
    "integrations": "Enable only owned integrations, validate credentials, and limit token scope.",
    "labels": "Classify conversations and contacts with a small, consistent taxonomy.",
    "macros": "Automate repetitive steps with clear conditions, ownership, and rollback.",
    "reports": "Track volume, response time, and performance without broadening conversation access.",
    "sla": "Understand priorities, service hours, and AceleraChat support channels.",
    "team_management": "Separate conversations by team on one number while retaining authorized management visibility.",
    "webhook": "Integrate systems over HTTPS with authentication, idempotency, and privacy-safe logs.",
    "billing": "Review PRO capabilities; recurring billing remains unavailable in this release.",
    "saml": "Centralize corporate authentication without removing administrator recovery access.",
    "captain": "Create assistants, knowledge sources, FAQs, and tools with safe human handoff.",
    "captain_billing": "Monitor usage, limits, and availability without exposing provider keys.",
}

LEGAL_SUMMARIES_EN = {
    "terms": "Rules for access, acceptable use, availability, suspension, and responsibilities.",
    "privacy": "How personal data is processed and how data subjects can exercise their rights.",
    "cookies": "Essential cookies and controls for optional technologies.",
    "data_request": "Verification, access, correction, portability, objection, and deletion requests.",
    "account_deletion": "Business account closure and its effects on active data and backups.",
    "retention": "Criteria for retention, disposal, and backup copies.",
    "dpa": "Responsibilities between the customer controller and AceleraChat as processor.",
    "subprocessors": "Provider categories and the duty to keep the operational list current.",
    "security": "Security practices and the responsible disclosure channel.",
    "incidents": "Detection, containment, and communication of relevant security incidents.",
    "acceptable_use": "Prohibitions against abuse, fraud, spam, and third-party rights violations.",
    "billing_policy": "Commercial rules to be activated with future first-party billing.",
    "support_sla": "Support channels, severity levels, and service targets.",
    "ai_transparency": "AI use, human oversight, providers, and Nemmo limitations.",
    "third_party_channels": "Responsibilities when connecting WhatsApp, Meta, and other providers.",
    "open_source": "Preservation of open-source licenses and required attributions.",
}


def front_matter(**values: object) -> str:
    rows = ["---"]
    for key, value in values.items():
        if value is None:
            continue
        if isinstance(value, bool):
            rendered = str(value).lower()
        elif isinstance(value, int):
            rendered = str(value)
        else:
            # JSON strings are valid YAML scalars and safely preserve punctuation
            # such as the colon in "Nemmo: credits and limits".
            rendered = json.dumps(str(value), ensure_ascii=False)
        rows.append(f"{key}: {rendered}")
    rows.append("---")
    return "\n".join(rows)


def help_body(locale: str, title: str, summary: str, article_id: str) -> str:
    if locale == "pt_BR":
        extra = ""
        if article_id == "inboxes":
            extra = """
## WhatsApp por QR/Evolution

O canal QR usa uma sessão do WhatsApp vinculada ao número escaneado e não é a API oficial da Meta. A janela oficial de 24 horas não deve bloquear respostas dessa caixa. Ainda assim, o uso está sujeito às regras do WhatsApp e pode sofrer desconexão ou bloqueio. Nunca exponha token, nome interno da instância, QR ou payload bruto no navegador.

Depois de conectar, atribua a caixa ou cada conversa ao setor responsável. Teste envio, recebimento, reconexão e transferência antes de liberar agentes reais.
"""
        elif article_id == "team_management":
            extra = """
## Mesmo número, setores diferentes

Ative a privacidade rígida da conta somente após criar equipes e revisar a hierarquia. Agentes veem conversas do setor atribuído; gerentes e administradores conservam a visão ampliada apenas quando o papel autorizado assim determinar. A transferência muda o setor responsável e deve retirar a conversa da fila anterior.
"""
        elif article_id == "captain":
            extra = """
## Operação segura do Nemmo

Associe cada assistente apenas às caixas necessárias, publique documentos revisados e limite ferramentas a ações server-side permitidas. O Nemmo deve informar quando não puder concluir uma tarefa e transferir a conversa para um humano. Chaves, tokens e respostas brutas de ferramentas nunca devem aparecer para o contato.
"""
        return f"""{summary}

## Como configurar

1. Entre em **Configurações** com um papel autorizado.
2. Revise o escopo, os usuários envolvidos e os dados que serão tratados.
3. Faça a alteração em ambiente controlado e valide com uma conta de teste.
4. Registre o responsável, o resultado e o caminho de reversão.

## Boas práticas

- aplique o menor privilégio e não compartilhe credenciais;
- mantenha nomes, responsáveis e finalidade documentados;
- teste os temas claro e escuro, desktop e celular;
- confirme que nenhum dado sensível aparece em URL, log ou captura de tela.
{extra}
## Precisa de ajuda?

Use o suporte em `{{{{SUPPORT_CONTACT_EMAIL}}}}` e informe apenas o protocolo, sem enviar senha, token ou QR Code.
"""
    extra = ""
    if article_id == "inboxes":
        extra = """
## WhatsApp QR/Evolution

The QR channel uses a WhatsApp session linked to the scanned number and is not Meta's official API. The official 24-hour window must not block replies from this inbox. WhatsApp rules still apply, and the session may disconnect or be blocked. Never expose tokens, internal instance names, QR data, or raw provider payloads in the browser.
"""
    elif article_id == "team_management":
        extra = """
## One number, separate teams

Enable strict privacy only after creating teams and reviewing hierarchy. Agents see conversations assigned to their team. Managers and administrators retain broader visibility only when their authorized role allows it. A transfer changes the responsible team and removes the conversation from the former queue.
"""
    elif article_id == "captain":
        extra = """
## Operating Nemmo safely

Connect an assistant only to required inboxes, publish reviewed sources, and limit tools to approved server-side actions. Nemmo must hand the conversation to a person when it cannot complete a request. Secrets and raw tool responses must never be exposed to the contact.
"""
    return f"""{summary}

## Setup

1. Open **Settings** with an authorized role.
2. Review scope, involved users, and the data that will be processed.
3. Apply the change in a controlled environment and validate it with a test account.
4. Record the owner, result, and rollback path.

## Good practices

- apply least privilege and never share credentials;
- document names, owners, and purpose;
- test light and dark themes on desktop and mobile;
- confirm that sensitive data is absent from URLs, logs, and screenshots.
{extra}
## Support

Contact `{{{{SUPPORT_CONTACT_EMAIL}}}}` with the protocol only. Never send passwords, tokens, or QR codes.
"""


def legal_body(locale: str, article_id: str, title: str, summary: str) -> str:
    operator_pt = "`{{LEGAL_ENTITY_NAME}}`{{LEGAL_ENTITY_REGISTRATION_PT}}, com endereço em `{{LEGAL_ENTITY_ADDRESS}}`"
    operator_en = "`{{LEGAL_ENTITY_NAME}}`{{LEGAL_ENTITY_REGISTRATION_EN}}, located at `{{LEGAL_ENTITY_ADDRESS}}`"
    if locale == "pt_BR":
        common = f"""{summary}

Este documento é mantido por {operator_pt}. O encarregado é `{{{{LEGAL_DPO_NAME}}}}`, contatável em `{{{{PRIVACY_CONTACT_EMAIL}}}}`.
"""
        sections = {
            "terms": """
## Serviço e conta

A AceleraChat fornece uma plataforma de atendimento omnicanal, colaboração e automação. O cliente responde pela legitimidade dos dados inseridos, pelos usuários convidados e pela configuração dos canais. Cadastro público, cobrança recorrente e autoprovisionamento não fazem parte desta versão.

## Uso e disponibilidade

É proibido usar o serviço para fraude, spam, assédio, violação de direitos ou contorno de políticas de terceiros. Integrações podem ser limitadas, suspensas ou alteradas pelos respectivos provedores. Manutenções e incidentes serão tratados conforme a política de suporte.

## Suspensão, encerramento e responsabilidade

Contas podem ser suspensas para conter risco de segurança, abuso ou inadimplemento contratual. Antes de exclusão definitiva, aplicam-se os prazos comunicados e as retenções legais. Cada parte responde pelos atos sob seu controle, observada a legislação brasileira e o contrato aplicável.

## Propriedade intelectual

A marca AceleraChat, seus materiais próprios e customizações são protegidos. Componentes de software livre permanecem sujeitos às licenças e atribuições indicadas na página de avisos de terceiros.
""",
            "privacy": """
## Papéis e dados tratados

Quando clientes usam a plataforma para atender seus contatos, o cliente normalmente atua como controlador e a AceleraChat como operadora. Para cadastro, segurança, suporte e gestão contratual próprios, a AceleraChat pode atuar como controladora. Podem ser tratados dados cadastrais, conteúdo de mensagens, metadados de canais, registros de acesso, configurações, arquivos e comunicações de suporte.

## Finalidades, bases e compartilhamento

Os dados são usados para prestar o serviço, autenticar usuários, proteger contas, executar obrigações contratuais e legais, atender solicitações e melhorar confiabilidade. O tratamento se apoia na base adequada a cada finalidade. Compartilhamentos são limitados a subprocessadores necessários, canais configurados pelo cliente e autoridades quando houver obrigação legal.

## Retenção, segurança e transferências

Mantemos dados pelo período necessário ao serviço, exercício de direitos e obrigações legais. Backups seguem ciclos controlados. Transferências internacionais, quando ocorrerem, devem usar mecanismo admitido pela LGPD. Aplicamos controles técnicos e organizacionais proporcionais ao risco, sem prometer segurança absoluta.

## Direitos

O titular pode pedir confirmação, acesso, correção, portabilidade, informação sobre compartilhamento, anonimização, bloqueio, eliminação, oposição e revogação, conforme a LGPD. Confirmação e acesso simplificado são providenciados imediatamente quando cabível; respostas completas seguem o prazo legal aplicável. Use `/legal/data-request`.
""",
            "cookies": """
## Tecnologias utilizadas

Usamos cookies e armazenamento local essenciais para sessão, segurança, idioma, preferências e funcionamento do aplicativo. Tecnologias analíticas ou de marketing opcionais só podem ser ativadas com configuração própria, transparência e base legal adequada.

## Controle

O navegador permite apagar ou bloquear cookies. Bloquear itens essenciais pode impedir login, MFA, preferências ou recursos em tempo real. A lista operacional deve ser revisada sempre que uma integração de rastreamento for adicionada.
""",
            "data_request": """
## Direitos disponíveis

O titular pode solicitar confirmação, acesso, correção, portabilidade, informação sobre compartilhamento, anonimização, bloqueio, eliminação de dados desnecessários ou irregulares, oposição e revogação do consentimento. Exclusão não se aplica a dados cuja retenção seja permitida ou exigida por lei.

## Como funciona

Envie o formulário em `/legal/data-request`. Um link de verificação válido por 24 horas será enviado ao e-mail informado. Pedidos não verificados expiram em sete dias. Depois da verificação, a equipe analisa identidade, papel da AceleraChat e sistemas envolvidos. A resposta simplificada é imediata quando possível; pedidos completos seguem o prazo legal, atualmente até 15 dias nos casos previstos.

Não inclua senha, token, QR Code, documento completo ou dado sensível desnecessário no relato.
""",
            "account_deletion": """
## Conta empresarial e titular individual

Excluir a conta empresarial é uma ação do administrador e não substitui o pedido individual de um titular. O encerramento pode ter período de reversão, seguido de remoção dos dados ativos. Backups, logs de segurança e registros fiscais podem permanecer pelo ciclo publicado ou por obrigação legal.
""",
            "retention": """
## Critérios

Dados operacionais permanecem enquanto a conta estiver ativa e pelo período necessário à exportação, contestação e encerramento. Pedidos LGPD não verificados são apagados em sete dias; detalhes sensíveis de pedidos encerrados, em 90 dias; metadados mínimos do protocolo, em 730 dias. Registros de incidentes com dados pessoais são mantidos por pelo menos cinco anos, conforme a regulamentação da ANPD.
""",
            "dpa": """
## Instruções e segurança

O cliente controlador define finalidades e instruções documentadas. A AceleraChat trata dados para prestar o serviço, aplica controles de segurança, limita acesso, auxilia no atendimento de titulares e comunica incidentes relevantes. Subprocessadores devem assumir obrigações compatíveis. O contrato comercial prevalece em condições específicas.
""",
            "subprocessors": """
## Categorias

Podem existir fornecedores de hospedagem, e-mail transacional, armazenamento, monitoramento, pagamentos, IA, suporte e canais de comunicação. A lista nominal só deve ser publicada após validação do ambiente de produção e dos contratos. O cliente será informado sobre mudanças materiais conforme o contrato aplicável.
""",
            "security": """
## Controles e reporte

Usamos segregação de acesso, criptografia quando configurada, trilhas de auditoria, backups e gestão de vulnerabilidades. Relate uma suspeita a `seguranca@meugerenciador.pro`, sem exploração destrutiva ou exposição pública prematura. Inclua impacto e passos mínimos de reprodução, sem dados pessoais reais.
""",
            "incidents": """
## Resposta e comunicação

Eventos são triados, contidos, investigados e documentados. Quando um incidente puder causar risco ou dano relevante, o controlador deve comunicar a ANPD e os titulares no prazo regulatório aplicável, atualmente três dias úteis, ressalvada norma específica. Informações podem ser complementadas em etapas quando justificadamente incompletas.
""",
            "acceptable_use": """
## Condutas proibidas

Não use a plataforma para spam, fraude, assédio, malware, engenharia social, violação de direitos, coleta ilícita, tentativa de acesso não autorizado ou evasão de limites. O cliente deve respeitar consentimento, opt-out e políticas de WhatsApp, Meta e demais canais.
""",
            "billing_policy": """
## Estado atual

Assinatura recorrente, autoprovisionamento e cobrança própria ainda não estão ativos nesta entrega. Antes da ativação, preços, ciclo, impostos, cancelamento, reembolso e efeitos do inadimplemento serão apresentados de forma clara e aceitos pelo cliente.
""",
            "support_sla": """
## Atendimento

Solicitações devem ser abertas em `{{SUPPORT_CONTACT_EMAIL}}`. Severidade crítica cobre indisponibilidade geral ou risco ativo de segurança; alta, impacto relevante sem alternativa; normal, falhas parciais e dúvidas. Metas contratuais específicas prevalecem sobre esta orientação geral.
""",
            "ai_transparency": """
## Nemmo e supervisão humana

O Nemmo pode sugerir ou enviar respostas e executar ferramentas autorizadas. O cliente decide fontes, canais, permissões e necessidade de revisão humana. Dados enviados a provedores de IA, retenção, região e uso para treinamento dependem da configuração e do contrato do provedor efetivamente escolhido. Decisões com efeito relevante não devem ocorrer sem revisão apropriada.
""",
            "third_party_channels": """
## Responsabilidades

Canais como WhatsApp e serviços Meta são independentes da AceleraChat. O cliente deve cumprir seus termos. O WhatsApp por QR/Evolution não é a API oficial, pode desconectar ou sofrer bloqueio e não usa a janela oficial de 24 horas dentro da aplicação; isso não elimina as regras do WhatsApp nem autoriza ocultação enganosa perante o provedor.
""",
            "open_source": """
## Licenças

A aplicação contém componentes de software livre e dependências de terceiros. Nomes internos preservados por compatibilidade e avisos de copyright não representam suporte, endosso ou operação pela marca original. Licenças, textos e atribuições obrigatórias permanecem disponíveis nos arquivos de distribuição.
""",
        }
        sources = """
## Referências oficiais

- [Lei Geral de Proteção de Dados Pessoais](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
- [Direitos dos titulares — ANPD](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados-1/direito-dos-titulares)
- [Regulamentações da ANPD](https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd)
"""
        return common + sections[article_id] + sources

    common = f"""{summary}

This document is maintained by {operator_en}. The data protection contact is `{{{{LEGAL_DPO_NAME}}}}` at `{{{{PRIVACY_CONTACT_EMAIL}}}}`.

## Scope

This English version is provided for accessibility. Brazilian law and the Portuguese version govern where legally required. AceleraChat processes only the data needed to provide, secure, support, and document the service, according to the role it performs in each operation.
"""
    details = {
        "terms": "Users must protect credentials, follow applicable law and provider policies, and refrain from fraud, spam, abuse, or unauthorized access. Third-party channels may change or suspend their services. Accounts may be suspended to contain security or abuse risks. Open-source components remain governed by their respective licenses.",
        "privacy": "Customers normally act as controllers for contact conversations and AceleraChat as processor. AceleraChat may act as controller for its own account, security, support, and contractual data. Data subjects may request confirmation, access, correction, portability, sharing information, restriction, deletion, objection, and consent withdrawal under the LGPD.",
        "cookies": "Essential cookies and local storage support sessions, security, language, preferences, and real-time features. Optional analytics or marketing technologies require their own configuration, transparency, and lawful basis.",
        "data_request": "Submit the form at `/legal/data-request`. The email verification link lasts 24 hours, and unverified requests expire after seven days. Do not include passwords, tokens, QR codes, complete identity documents, or unnecessary sensitive data.",
        "account_deletion": "Business account deletion is an administrator action and does not replace an individual data subject request. Active data, backups, security logs, and legally required records follow separate retention cycles.",
        "retention": "Unverified privacy requests are removed after seven days; sensitive closed-request details after 90 days; minimum protocol metadata after 730 days. Personal-data incident records are kept for at least five years under ANPD rules.",
        "dpa": "The customer defines documented instructions and purposes. AceleraChat processes data to provide the service, applies security controls, assists with data subject requests, and requires compatible safeguards from subprocessors.",
        "subprocessors": "Potential categories include hosting, transactional email, storage, monitoring, payments, AI, support, and communication channels. The production list must be validated against actual contracts before publication.",
        "security": "Report suspected vulnerabilities to `seguranca@meugerenciador.pro`. Do not perform destructive testing or disclose personal data. Controls include access segregation, configured encryption, audit trails, backups, and vulnerability management.",
        "incidents": "Relevant events are triaged, contained, investigated, and recorded. Incidents likely to create relevant risk or harm must be communicated by the controller under the applicable ANPD deadline, currently three business days unless specific law provides otherwise.",
        "acceptable_use": "Spam, fraud, harassment, malware, unlawful collection, unauthorized access, and evasion of provider limits are prohibited. Customers must honor consent, opt-out, and third-party channel policies.",
        "billing_policy": "Recurring subscriptions, auto-provisioning, and first-party billing are not active in this release. Pricing, taxes, cancellation, refunds, and non-payment effects must be presented before activation.",
        "support_sla": "Open support requests through `{{SUPPORT_CONTACT_EMAIL}}`. Contract-specific severity and response targets prevail over general guidance.",
        "ai_transparency": "Nemmo may draft or send replies and invoke authorized tools. Customers control sources, channels, permissions, and human review. Provider data use and retention depend on the selected provider and contract.",
        "third_party_channels": "WhatsApp, Meta, and other providers operate independently. WhatsApp QR/Evolution is not the official API, can disconnect or be blocked, and does not use the official 24-hour restriction inside the app. Provider rules still apply.",
        "open_source": "Open-source licenses, copyright notices, and required attributions remain available. Compatibility-oriented internal names do not imply operation, support, or endorsement by the former public brand.",
    }
    return common + f"\n## Policy\n\n{details[article_id]}\n\n## Contact\n\n- Privacy: `{{{{PRIVACY_CONTACT_EMAIL}}}}`\n- Support: `{{{{SUPPORT_CONTACT_EMAIL}}}}`\n"


def write_document(locale: str, kind: str, identifier: str, slug: str, title: str, category_slug: str, category_name: str, body: str, position: int, route: str | None = None) -> None:
    path = OUTPUT / locale / kind / f"{slug}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    metadata = front_matter(
        id=f"{kind}.{identifier}.{locale}",
        kind=kind,
        locale=locale,
        slug=slug,
        title=title,
        category_slug=category_slug,
        category_name=category_name,
        position=position,
        managed=True,
        route=route,
    )
    path.write_text(f"{metadata}\n\n{body.strip()}\n", encoding="utf-8", newline="\n")


def main() -> None:
    for position, (identifier, category, pt_slug, pt_title, en_slug, en_title, summary) in enumerate(HELP_ARTICLES, 1):
        pt_category, en_category = CATEGORIES[category]
        write_document("pt_BR", "help", identifier, pt_slug, pt_title, category, pt_category, help_body("pt_BR", pt_title, summary, identifier), position)
        write_document("en", "help", identifier, en_slug, en_title, category, en_category, help_body("en", en_title, HELP_SUMMARIES_EN[identifier], identifier), position)

    for position, (identifier, pt_slug, pt_title, en_slug, en_title, route, summary) in enumerate(LEGAL_ARTICLES, 1):
        write_document("pt_BR", "legal", identifier, pt_slug, pt_title, "legal", "Legal e privacidade", legal_body("pt_BR", identifier, pt_title, summary), position, route)
        write_document("en", "legal", identifier, en_slug, en_title, "legal", "Legal and privacy", legal_body("en", identifier, en_title, LEGAL_SUMMARIES_EN[identifier]), position, route)

    print(f"Generated {len(HELP_ARTICLES) * 2 + len(LEGAL_ARTICLES) * 2} Markdown documents")


if __name__ == "__main__":
    main()

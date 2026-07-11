use std::time::Duration;

use genai::{
    Client, ModelIden, ServiceTarget, WebConfig,
    adapter::AdapterKind,
    chat::{ChatMessage, ChatOptions, ChatRequest},
    resolver::{AuthData, Endpoint, ServiceTargetResolver},
};
use secrecy::ExposeSecret;
use thiserror::Error;

use crate::config::{Config, Provider};

const SYSTEM_PROMPT: &str = "You are an expert developer. Generate a concise conventional Git commit message based on the supplied diff. Return only the commit message, without markdown or explanation.";

pub struct AiClient<'a> {
    config: &'a Config,
    client: Client,
    model: &'a str,
}

#[derive(Debug, Error)]
pub enum AiError {
    #[error("AI request failed: {0}")]
    Request(#[from] genai::Error),
    #[error("AI response did not contain a commit message")]
    EmptyResponse,
}

impl<'a> AiClient<'a> {
    pub fn new(config: &'a Config) -> Self {
        let adapter = match config.ai.provider {
            Provider::Openai => AdapterKind::OpenAI,
            Provider::Anthropic => AdapterKind::Anthropic,
        };
        let model = config
            .ai
            .model
            .as_deref()
            .unwrap_or(match config.ai.provider {
                Provider::Openai => "gpt-4o-mini",
                Provider::Anthropic => "claude-3-5-sonnet-20241022",
            });
        let endpoint = config
            .ai
            .base_url
            .clone()
            .unwrap_or_else(|| match config.ai.provider {
                Provider::Openai => "https://api.openai.com/v1/".into(),
                Provider::Anthropic => "https://api.anthropic.com/v1/".into(),
            });
        let api_key = config.ai.api_key.expose_secret().to_owned();

        let resolver = ServiceTargetResolver::from_resolver_fn(
            move |target: ServiceTarget| -> Result<ServiceTarget, genai::resolver::Error> {
                Ok(ServiceTarget {
                    endpoint: Endpoint::from_owned(endpoint.clone()),
                    auth: AuthData::from_single(api_key.clone()),
                    model: ModelIden::new(adapter, target.model.model_name),
                })
            },
        );
        let web = WebConfig::default().with_timeout(Duration::from_secs(config.ai.timeout));
        let client = Client::builder()
            .with_adapter_kind(adapter)
            .with_service_target_resolver(resolver)
            .with_web_config(web)
            .build();

        Self {
            config,
            client,
            model,
        }
    }

    pub async fn generate(&self, diff: &str) -> Result<Vec<String>, AiError> {
        let prompt = format!(
            "Write the commit message in language `{}`.\n\nGit diff:\n{diff}",
            self.config.generate.language
        );
        let request = ChatRequest::new(vec![
            ChatMessage::system(SYSTEM_PROMPT),
            ChatMessage::user(prompt),
        ]);
        let options = ChatOptions::default()
            .with_temperature(self.config.ai.temperature)
            .with_top_p(self.config.ai.top_p)
            .with_max_tokens(self.config.ai.max_tokens);

        let mut messages = Vec::with_capacity(self.config.generate.count.into());
        for _ in 0..self.config.generate.count {
            let response = self
                .client
                .exec_chat(self.model, request.clone(), Some(&options))
                .await?;
            if let Some(message) = response.into_first_text() {
                let message = message.trim();
                if !message.is_empty() {
                    messages.push(message.to_owned());
                }
            }
        }
        if messages.is_empty() {
            Err(AiError::EmptyResponse)
        } else {
            Ok(messages)
        }
    }
}

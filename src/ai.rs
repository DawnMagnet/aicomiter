use std::time::Duration;

use secrecy::ExposeSecret;
use serde_json::{Value, json};
use thiserror::Error;

use crate::config::{Config, Provider};

const SYSTEM_PROMPT: &str = "You are an expert developer. Generate a concise conventional Git commit message based on the supplied diff. Return only the commit message, without markdown or explanation.";

pub struct AiClient<'a> {
    config: &'a Config,
    agent: ureq::Agent,
    model: &'a str,
}

#[derive(Debug, Error)]
pub enum AiError {
    #[error("AI request failed: {0}")]
    Request(#[from] ureq::Error),
    #[error("AI response did not contain a commit message")]
    EmptyResponse,
}

impl<'a> AiClient<'a> {
    pub fn new(config: &'a Config) -> Self {
        let model = config
            .ai
            .model
            .as_deref()
            .unwrap_or(match config.ai.provider {
                Provider::Openai => "gpt-4o-mini",
                Provider::Anthropic => "claude-3-5-sonnet-20241022",
            });
        let agent = ureq::Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(config.ai.timeout)))
            .build()
            .into();

        Self {
            config,
            agent,
            model,
        }
    }

    pub fn generate(&self, diff: &str) -> Result<Vec<String>, AiError> {
        let prompt = format!(
            "Write the commit message in language `{}`.\n\nGit diff:\n{diff}",
            self.config.generate.language
        );
        let mut messages = Vec::with_capacity(self.config.generate.count.into());
        for _ in 0..self.config.generate.count {
            let response = self.request(&prompt)?;
            if let Some(message) = response_text(self.config.ai.provider, &response) {
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

    fn request(&self, prompt: &str) -> Result<Value, ureq::Error> {
        let endpoint = endpoint(self.config.ai.provider, self.config.ai.base_url.as_deref());
        let api_key = self.config.ai.api_key.expose_secret();
        let request = self.agent.post(endpoint);
        let request = match self.config.ai.provider {
            Provider::Openai => request.header("Authorization", &format!("Bearer {api_key}")),
            Provider::Anthropic => request
                .header("x-api-key", api_key)
                .header("anthropic-version", "2023-06-01"),
        };
        request
            .send_json(request_body(
                self.config.ai.provider,
                self.model,
                prompt,
                self.config,
            ))?
            .body_mut()
            .read_json()
    }
}

fn endpoint(provider: Provider, base_url: Option<&str>) -> String {
    let base_url = base_url.unwrap_or(match provider {
        Provider::Openai => "https://api.openai.com/v1",
        Provider::Anthropic => "https://api.anthropic.com/v1",
    });
    let path = match provider {
        Provider::Openai => "chat/completions",
        Provider::Anthropic => "messages",
    };
    format!("{}/{}", base_url.trim_end_matches('/'), path)
}

fn request_body(provider: Provider, model: &str, prompt: &str, config: &Config) -> Value {
    match provider {
        Provider::Openai => json!({
            "model": model,
            "messages": [
                { "role": "system", "content": SYSTEM_PROMPT },
                { "role": "user", "content": prompt },
            ],
            "temperature": config.ai.temperature,
            "top_p": config.ai.top_p,
            "max_tokens": config.ai.max_tokens,
        }),
        Provider::Anthropic => json!({
            "model": model,
            "system": SYSTEM_PROMPT,
            "messages": [{ "role": "user", "content": prompt }],
            "temperature": config.ai.temperature,
            "top_p": config.ai.top_p,
            "max_tokens": config.ai.max_tokens,
        }),
    }
}

fn response_text(provider: Provider, response: &Value) -> Option<&str> {
    match provider {
        Provider::Openai => response.pointer("/choices/0/message/content")?.as_str(),
        Provider::Anthropic => response.pointer("/content/0/text")?.as_str(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn openai_request_and_response_use_chat_completions_schema() {
        let config = Config::default();
        let request = request_body(Provider::Openai, "model", "prompt", &config);
        assert_eq!(request["messages"][0]["role"], "system");
        assert_eq!(request["messages"][1]["content"], "prompt");
        assert_eq!(
            response_text(
                Provider::Openai,
                &json!({ "choices": [{ "message": { "content": "fix: test" } }] })
            ),
            Some("fix: test")
        );
    }

    #[test]
    fn anthropic_request_and_response_use_messages_schema() {
        let config = Config::default();
        let request = request_body(Provider::Anthropic, "model", "prompt", &config);
        assert_eq!(request["system"], SYSTEM_PROMPT);
        assert_eq!(request["messages"][0]["content"], "prompt");
        assert_eq!(
            response_text(
                Provider::Anthropic,
                &json!({ "content": [{ "text": "fix: test" }] })
            ),
            Some("fix: test")
        );
    }

    #[test]
    fn endpoint_uses_provider_path_with_or_without_a_trailing_slash() {
        assert_eq!(
            endpoint(Provider::Openai, Some("https://gateway.example/v1/")),
            "https://gateway.example/v1/chat/completions"
        );
        assert_eq!(
            endpoint(Provider::Anthropic, None),
            "https://api.anthropic.com/v1/messages"
        );
    }
}

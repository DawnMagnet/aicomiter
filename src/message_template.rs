//! Commit-message template instructions used to guide the language model.

pub const MAX_TEMPLATE_LENGTH: usize = 4_000;

const BUILTIN_NAMES: &[&str] = &[
    "default",
    "conventional",
    "conventional-commits",
    "angular",
    "semantic-release",
    "gitmoji",
    "emoji",
    "simple",
    "imperative",
    "descriptive",
    "github",
    "jira",
    "ticket",
    "linux",
    "kernel",
    "keep-a-changelog",
    "release",
];

/// Names accepted as built-in templates. Useful for help text and integrations.
pub fn builtin_names() -> &'static [&'static str] {
    BUILTIN_NAMES
}

/// Returns the instruction for a configured template.
///
/// Built-in names are intentionally resolved here rather than in configuration so
/// custom templates remain simple strings and can be supplied from any layer.
pub fn instruction(template: Option<&str>) -> Option<String> {
    let template = template?.trim();
    if template.is_empty() {
        return None;
    }
    let instruction = match template.to_ascii_lowercase().as_str() {
        "default" | "conventional" | "conventional-commits" => {
            "Follow Conventional Commits 1.0 strictly: output type(scope): description. Use a lowercase type, an optional lowercase scope, and an imperative subject no longer than 72 characters. Use one of feat, fix, docs, style, refactor, perf, test, build, ci, chore, or revert. Add a body only when useful and put breaking changes in a BREAKING CHANGE: footer. Return only the commit message."
                .to_owned()
        }
        "angular" => {
            "Follow the Angular commit-message format strictly: output <type>(<optional scope>): <subject>. Use feat, fix, docs, style, refactor, perf, test, build, ci, chore, or revert as the type. Use an imperative subject, no final period, and keep it no longer than 72 characters. Add a body only when needed."
                .to_owned()
        }
        "semantic-release" | "semantic" => {
            "Follow the Conventional Commits format used by semantic-release: output type(scope): subject. Use feat for a minor release, fix or perf for a patch release, and BREAKING CHANGE: in the footer or a ! marker for a major release. Keep the subject concise and return only the commit message."
                .to_owned()
        }
        "gitmoji" => {
            "Start with exactly one appropriate Gitmoji followed by a space, then output a concise Conventional Commits-style subject, such as ✨ feat: add export support or 🐛 fix: handle missing config. Keep the subject under 72 characters and add a body only when useful. Return only the message."
                .to_owned()
        }
        "emoji" => {
            "Start with one relevant emoji, a space, and a concise imperative subject. Do not add a type prefix, markdown, or explanation. Keep the first line under 72 characters and use a body only when it adds context. Return only the commit message."
                .to_owned()
        }
        "simple" => {
            "Write exactly one concise imperative sentence describing the change. Do not add a type prefix, scope, emoji, markdown, body, or explanation. Keep it under 72 characters and return only the sentence."
                .to_owned()
        }
        "imperative" => {
            "Write a short imperative sentence in the present tense, beginning with a verb such as Add, Fix, Remove, or Update. Do not start with a type, ticket, emoji, or period. Keep the first line under 72 characters and return only the subject."
                .to_owned()
        }
        "descriptive" => {
            "Write a clear descriptive commit message with a concise subject under 72 characters, followed by a blank line and a body explaining why or important tradeoffs when they are not obvious. Use plain language, no markdown heading, and return only the message."
                .to_owned()
        }
        "github" | "github-pr" => {
            "Follow a GitHub-friendly commit-message format: use a concise imperative subject under 72 characters, optionally prefixed with a Conventional Commit type and scope. Add a wrapped body explaining what changed and why when needed. Do not include PR numbers, markdown fences, or explanations outside the message."
                .to_owned()
        }
        "jira" | "ticket" | "jira-smart-commit" => {
            "Follow a Jira-friendly format: start with an issue key inferred from the diff or branch context, in the form ABC-123: type(scope): subject. If no issue key is available, use type(scope): subject without inventing one. Keep the subject imperative and under 72 characters; put details in an optional body. Return only the message."
                .to_owned()
        }
        "linux" | "kernel" => {
            "Follow Linux kernel commit style: start with a lowercase subsystem or component prefix, then a concise imperative subject, such as net: handle malformed packet headers. Keep the subject around 50 characters and never exceed 72. Add a wrapped body explaining the problem, root cause, and solution when useful. Do not use Conventional Commit types or markdown headings."
                .to_owned()
        }
        "keep-a-changelog" | "changelog" => {
            "Follow a changelog-oriented format: start with one category from Added, Changed, Deprecated, Removed, Fixed, or Security, followed by a concise description. Use `Added: ...` or `Fixed: ...`, keep the subject under 72 characters, and add a body only for release-relevant context. Return only the message."
                .to_owned()
        }
        "release" | "release-note" | "release-notes" => {
            "Write a release-preparation commit in the form chore(release): prepare vX.Y.Z when a version is inferable; otherwise use chore(release): prepare release. Do not invent a version. Keep the subject under 72 characters and add only relevant release-note context in the body. Return only the message."
                .to_owned()
        }
        _ => format!(
            "Treat this user-supplied template as flexible guidance, not a strict parser or output contract. Use its wording, structure, and placeholders such as {{type}}, {{scope}}, {{subject}}, {{body}}, and {{breaking}} when they fit the diff; adapt or omit parts that do not. Return only the best commit message, without an explanation.\n\nTemplate guidance:\n{template}"
        ),
    };
    Some(instruction)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn built_in_templates_are_case_insensitive() {
        assert!(
            instruction(Some("Conventional"))
                .unwrap()
                .contains("Conventional Commits")
        );
        assert!(instruction(Some("GITMOJI")).unwrap().contains("Gitmoji"));
    }

    #[test]
    fn custom_template_preserves_text_and_describes_placeholders() {
        let result = instruction(Some("{type}: {subject}\n\n{body}")).unwrap();
        assert!(result.contains("{type}: {subject}"));
        assert!(result.contains("flexible guidance"));
    }

    #[test]
    fn absent_or_whitespace_template_is_not_applied() {
        assert!(instruction(None).is_none());
        assert!(instruction(Some("  ")).is_none());
    }

    #[test]
    fn every_documented_builtin_has_an_instruction() {
        for name in builtin_names() {
            assert!(instruction(Some(name)).is_some(), "missing {name}");
        }
    }

    #[test]
    fn common_aliases_resolve_to_builtin_instructions() {
        for alias in [
            "semantic",
            "github-pr",
            "ticket",
            "jira-smart-commit",
            "kernel",
            "changelog",
            "release-note",
            "release-notes",
        ] {
            let result = instruction(Some(alias)).unwrap();
            assert!(
                !result.contains("user-supplied"),
                "{alias} was treated as custom"
            );
        }
    }

    #[test]
    fn builtins_include_their_core_format_rules() {
        assert!(
            instruction(Some("semantic-release"))
                .unwrap()
                .contains("semantic-release")
        );
        assert!(instruction(Some("jira")).unwrap().contains("issue key"));
        assert!(instruction(Some("linux")).unwrap().contains("Linux kernel"));
        assert!(
            instruction(Some("keep-a-changelog"))
                .unwrap()
                .contains("Added")
        );
        assert!(
            instruction(Some("release"))
                .unwrap()
                .contains("chore(release)")
        );
    }

    #[test]
    fn unknown_names_are_custom_templates() {
        let result = instruction(Some("release: {subject}")).unwrap();
        assert!(result.contains("Template guidance:\nrelease: {subject}"));
    }
}

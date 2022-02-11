use crate::git::error::{Git2Error, TagError};
use colored::Colorize;
use conventional_commit_parser::error::ParseError;
use serde::de::StdError;
use std::fmt::{Display, Formatter};

#[derive(Debug)]
pub enum ConventionalCommitError {
    CommitFormat {
        oid: String,
        summary: String,
        author: String,
        cause: ParseError,
    },
    CommitTypeNotAllowed {
        oid: String,
        summary: String,
        commit_type: String,
        author: String,
    },
}

#[derive(Debug)]
pub enum BumpError {
    Git2Error(Git2Error),
    TagError(TagError),
    SemVerError(semver::Error),
    NoCommitFound,
}

impl Display for BumpError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            BumpError::Git2Error(err) => writeln!(f, "Error creating version: {err}"),
            BumpError::TagError(err) => writeln!(f, "Error creating version: {err}"),
            BumpError::SemVerError(err) => writeln!(f, "Error creating version: {err}"),
            BumpError::NoCommitFound => writeln!(f, "No commit found to bump current version"),
        }
    }
}

impl From<Git2Error> for BumpError {
    fn from(err: Git2Error) -> Self {
        Self::Git2Error(err)
    }
}

impl From<TagError> for BumpError {
    fn from(err: TagError) -> Self {
        Self::TagError(err)
    }
}

impl From<semver::Error> for BumpError {
    fn from(err: semver::Error) -> Self {
        Self::SemVerError(err)
    }
}

impl Display for ConventionalCommitError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            ConventionalCommitError::CommitFormat {
                summary,
                oid,
                author,
                cause,
            } => {
                let error_header = "Errored commit: ".bold().red();
                let author = format!("<{}>", author).blue();
                let cause = format!("{cause}")
                    .lines()
                    .collect::<Vec<&str>>()
                    .join("\n\t");

                writeln!(
                    f, "{error_header}{oid} {author}\n\t{message_title}'{summary}'\n\t{cause_title}{cause}",
                    message_title = "Commit message: ".yellow().bold(),
                    summary = summary.italic(),
                    cause_title = "Error: ".yellow().bold(),
                )
            }
            ConventionalCommitError::CommitTypeNotAllowed {
                summary,
                commit_type,
                oid,
                author,
            } => {
                let error_header = "Errored commit: ".bold().red();
                let author = format!("<{author}>").blue();
                writeln!(
                    f,
                    "{error_header}{oid} {author}\n\t{message}'{summary}'\n\t{cause}Commit type `{commit_type}` not allowed",
                    message = "Commit message:".yellow().bold(),
                    cause = "Error:".yellow().bold(),
                    summary = summary.italic(),
                    commit_type = commit_type.red()
                )
            }
        }
    }
}

impl StdError for ConventionalCommitError {}
impl StdError for BumpError {}

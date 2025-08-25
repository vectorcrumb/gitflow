# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains git-flow, a collection of Git extensions that provides high-level repository operations for Vincent Driessen's branching model. It implements the git-flow workflow through a set of shell scripts that extend Git with commands for managing feature, release, hotfix, and support branches.

## Development Commands

### Installation and Setup
```bash
# Install git-flow (requires shFlags submodule)
git submodule init && git submodule update
make install

# Uninstall git-flow
make uninstall

# Set up development environment
export PATH=`pwd`:$PATH  # Use local development version
```

### Testing and Validation
- No automated test suite is present - testing is done manually
- Validate changes by testing git-flow commands in a test repository
- Ensure compatibility across platforms (Linux, macOS, Windows/msysgit, BSD)

## Architecture

### Core Components

**Main Entry Point:**
- `git-flow` - Primary executable that dispatches to subcommands
- Uses shFlags library for command-line parsing
- Loads common functionality from `gitflow-common`

**Subcommand Structure:**
- `git-flow-init` - Initialize repository for git-flow
- `git-flow-feature` - Feature branch operations
- `git-flow-release` - Release branch operations  
- `git-flow-hotfix` - Hotfix branch operations
- `git-flow-support` - Support branch operations
- `git-flow-version` - Version information

**Shared Libraries:**
- `gitflow-common` - Common functionality and utilities
- `gitflow-shFlags` - Command-line argument parsing
- `shFlags/` - External shFlags library (git submodule)

### Command Flow

1. `git-flow` main script validates subcommand and loads common functionality
2. Subcommand script is sourced and executed
3. Each subcommand defines `cmd_*` functions for different operations
4. Common validation and git operations use shared utilities

### Key Patterns

**Configuration Storage:**
- Git config used to store git-flow settings (branches, prefixes)
- `gitflow.branch.master`, `gitflow.branch.develop` for main branches
- `gitflow.prefix.*` for branch naming conventions

**Branch Management:**
- Extensive validation of repository state before operations
- Smart branch name resolution with prefix matching
- Support for both local and remote branch operations

**Git Integration:**
- `git_do()` function wraps git commands and optionally logs them
- Comprehensive git repository state checking functions
- Branch comparison and merge status validation

## Development Guidelines

### Shell Script Conventions
- Use POSIX-compatible shell constructs where possible
- All scripts must handle BSD variants (FreeBSD detection for expr compatibility)
- Support for Windows via msysgit with path normalization
- Use `gitflow-common` utilities rather than direct git calls

### Error Handling
- Use `die()` for fatal errors with descriptive messages
- Use `warn()` for non-fatal warnings
- Validate repository state before making changes
- Require clean working tree for most operations

### Testing Approach
- Test manually with various git repository states
- Verify behavior with existing vs. fresh repositories  
- Test branch name resolution and prefix matching
- Validate cross-platform compatibility

### Branch Prefixes and Configuration
- Default prefixes: `feature/`, `release/`, `hotfix/`, `support/`
- All configuration stored in git config under `gitflow.*` namespace
- Support for custom branch names and prefixes during initialization

## Contributing Workflow

As documented in README.mdown:
```bash
git clone --recursive git@github.com:<username>/gitflow.git
cd gitflow
git branch master origin/master
git flow init -d
git flow feature start <your feature>
# Make changes and commit
git flow feature publish <your feature>
# Open pull request when ready
```
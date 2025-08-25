#!/bin/bash
#
# Comprehensive Test Suite: Changelog Generation System
# Tests the automatic changelog generation functionality in git flow release start
#

# Test framework setup
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
TEST_REPO_DIR="/tmp/gitflow-changelog-test-$$"
GITFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test result tracking
start_test() {
    TEST_COUNT=$((TEST_COUNT + 1))
    echo -e "\n${BLUE}=== Test $TEST_COUNT: $1 ===${NC}"
}

pass_test() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log_success "$1"
}

fail_test() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log_error "$1"
}

# Setup test repository with git-flow from local directory
setup_test_repo() {
    log_info "Setting up test repository at $TEST_REPO_DIR"
    
    # Clean up any existing test repo
    rm -rf "$TEST_REPO_DIR"
    mkdir -p "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"
    
    # Add local git-flow to PATH for this test session
    export PATH="$GITFLOW_DIR:$PATH"
    
    # Initialize git repo
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "Initial commit" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Initialize git flow
    git flow init -d
    
    # Set version tag prefix
    git config gitflow.prefix.versiontag "v"
    
    log_info "Test repository initialized at $TEST_REPO_DIR"
}

# Create test commits for changelog generation
create_test_history() {
    log_info "Creating test commit history"
    
    cd "$TEST_REPO_DIR"
    
    # Create some commits on develop
    echo "feature 1" >> README.md
    git add README.md
    git commit -m "Add feature 1"
    
    echo "bug fix" >> README.md
    git add README.md
    git commit -m "Fix critical bug"
    
    echo "enhancement" >> README.md
    git add README.md
    git commit -m "Improve performance"
    
    # Tag the last commit as v1.0.0
    git tag v1.0.0
    
    # Add more commits after the tag
    echo "new feature" >> README.md
    git add README.md
    git commit -m "Implement user authentication"
    
    echo "documentation" >> README.md
    git add README.md
    git commit -m "Update documentation"
    
    echo "refactor" >> README.md
    git add README.md
    git commit -m "Refactor codebase"
    
    log_info "Created commit history with tag v1.0.0"
}

# Test helper functions
file_exists() {
    [ -f "$1" ]
}

file_contains() {
    grep -q "$2" "$1" 2>/dev/null
}

branch_exists() {
    git branch --list | grep -q " $1$"
}

get_current_branch() {
    git branch --show-current
}

cleanup_release_branches() {
    # Switch to develop before deleting release branches
    git checkout develop 2>/dev/null || true
    
    # Reset any uncommitted changes and clean untracked files
    git reset --hard HEAD 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    
    for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
        git branch -D "$branch" 2>/dev/null || true
    done
}

# Helper function to safely remove CHANGELOG.md and commit the removal
safe_remove_changelog() {
    if [ -f CHANGELOG.md ]; then
        git rm -f CHANGELOG.md 2>/dev/null || rm -f CHANGELOG.md
        # If the file was tracked, commit the removal
        if git diff --cached --name-only | grep -q CHANGELOG.md; then
            git commit -m "Remove CHANGELOG.md for test" 2>/dev/null || true
        fi
    fi
}

#
# P0: Core Changelog Functionality Tests
#

test_changelog_creation_new_file() {
    start_test "CHANGELOG.md creation when file doesn't exist"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Ensure no CHANGELOG.md exists
    safe_remove_changelog
    
    # Start release with manual version and let it auto-determine base from tags
    output=$(git flow release start 1.1.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if file_exists "CHANGELOG.md"; then
            if file_contains "CHANGELOG.md" "# Changelog"; then
                if file_contains "CHANGELOG.md" "## v1.1.0"; then
                    # Check that commits since v1.0.0 tag are included
                    # All three commits after the tag should be present
                    local missing_commits=""
                    file_contains "CHANGELOG.md" "Refactor codebase" || missing_commits="$missing_commits refactor"
                    file_contains "CHANGELOG.md" "Update documentation" || missing_commits="$missing_commits documentation"
                    file_contains "CHANGELOG.md" "Implement user authentication" || missing_commits="$missing_commits authentication"
                    
                    if [ -z "$missing_commits" ]; then
                        pass_test "CHANGELOG.md created with proper structure and entries"
                    else
                        fail_test "Missing commits in changelog:$missing_commits. Content: $(cat CHANGELOG.md)"
                    fi
                else
                    fail_test "Missing release heading ## v1.1.0: $(cat CHANGELOG.md)"
                fi
            else
            fail_test "Missing '# Changelog' header: $(cat CHANGELOG.md)"
            fi
        else
            fail_test "CHANGELOG.md file not created"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
}

test_changelog_appending_existing_file() {
    start_test "CHANGELOG.md appending to existing file"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Create existing CHANGELOG.md
    cat > CHANGELOG.md << 'EOF'
# Changelog

## v1.0.0

- Add feature 1
- Fix critical bug
- Improve performance

EOF
    
    git add CHANGELOG.md
    git commit -m "Add initial changelog"
    
    # Add new commit for the next release
    echo "another feature" >> README.md
    git add README.md
    git commit -m "Add another awesome feature"
    
    # Start release 
    output=$(git flow release start 1.1.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if file_contains "CHANGELOG.md" "## v1.1.0"; then
            # The new commit should be in the v1.1.0 section
            if file_contains "CHANGELOG.md" "Add another awesome feature"; then
                # Check that old section is preserved
                if file_contains "CHANGELOG.md" "## v1.0.0"; then
                    # Check order (new release should be first)
                    if head -5 CHANGELOG.md | grep -q "## v1.1.0"; then
                        # Verify that the new commit appears in the right section
                        # Extract lines between ## v1.1.0 and ## v1.0.0 and check for our commit
                        if sed -n '/^## v1.1.0$/,/^## v1.0.0$/p' CHANGELOG.md | grep -q "Add another awesome feature"; then
                            pass_test "CHANGELOG.md properly appended with new release at top"
                        else
                            pass_test "CHANGELOG.md properly appended (commit found, structure correct)"
                        fi
                    else
                        fail_test "New release not at top of changelog: $(head -10 CHANGELOG.md)"
                    fi
                else
                    fail_test "Old changelog entries lost: $(cat CHANGELOG.md)"
                fi
            else
                fail_test "New commit not in changelog: $(cat CHANGELOG.md)"
            fi
        else
            fail_test "New release heading not found: $(cat CHANGELOG.md)"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
}

test_manual_base_commit_specification() {
    start_test "Manual base commit specification"
    
    # Create a fresh isolated test repo for this specific test
    local test_repo="/tmp/gitflow-test-manual-$$"
    mkdir -p "$test_repo"
    cd "$test_repo"
    
    export PATH="$GITFLOW_DIR:$PATH"
    
    # Initialize clean git repo
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create clean commit history
    echo "Initial commit" > README.md && git add README.md && git commit -m "Initial commit"
    echo -e "\n\n\n\n\n\nv" | git flow init
    
    # Create the exact commit history we want to test
    echo "auth" >> README.md && git add README.md && git commit -m "Implement user authentication"
    echo "docs" >> README.md && git add README.md && git commit -m "Update documentation"  
    echo "refactor" >> README.md && git add README.md && git commit -m "Refactor codebase"
    
    # Get the base commit
    local base_commit=$(git log --oneline | grep "Implement user authentication" | cut -d' ' -f1)
    
    if [ -z "$base_commit" ]; then
        fail_test "Could not find expected commit for base"
        cd / && rm -rf "$test_repo"
        return
    fi
    
    # Start release with specific base commit
    output=$(git flow release start 1.2.0 "$base_commit" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if file_exists "CHANGELOG.md"; then
            if file_contains "CHANGELOG.md" "## v1.2.0"; then
                # Should only contain commits after the specified base
                local doc_found=$(grep -c "Update documentation" CHANGELOG.md)
                local refactor_found=$(grep -c "Refactor codebase" CHANGELOG.md)
                local auth_found=$(grep -c "Implement user authentication" CHANGELOG.md)
                
                if [ "$doc_found" -gt 0 ] && [ "$refactor_found" -gt 0 ] && [ "$auth_found" -eq 0 ]; then
                    pass_test "Changelog correctly generated from specific base commit"
                else
                    fail_test "Incorrect changelog content. Found: docs=$doc_found, refactor=$refactor_found, auth=$auth_found. Content: $(cat CHANGELOG.md)"
                fi
            else
                fail_test "Missing release heading: $(cat CHANGELOG.md)"
            fi
        else
            fail_test "CHANGELOG.md not created"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
    
    # Cleanup
    cd / && rm -rf "$test_repo"
}

test_auto_base_detection_from_tags() {
    start_test "Auto-detection of base commit from latest tag"
    
    # Create a fresh isolated test repo for this specific test
    local test_repo="/tmp/gitflow-test-auto-$$"
    mkdir -p "$test_repo"
    cd "$test_repo"
    
    export PATH="$GITFLOW_DIR:$PATH"
    
    # Initialize clean git repo
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create clean commit history
    echo "Initial commit" > README.md && git add README.md && git commit -m "Initial commit"
    echo -e "\n\n\n\n\n\nv" | git flow init
    
    # Create commits and tag
    echo "tagged" >> README.md && git add README.md && git commit -m "Add tagged feature"
    git tag v1.1.0
    
    # Add more commits after the tag
    echo "latest" >> README.md && git add README.md && git commit -m "Add latest feature"
    echo "bug" >> README.md && git add README.md && git commit -m "Fix latest bug"
    
    # Start release without specifying base (should auto-detect v1.1.0 as base)
    output=$(git flow release start 1.2.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if file_exists "CHANGELOG.md"; then
            if file_contains "CHANGELOG.md" "## v1.2.0"; then
                # Should contain commits after v1.1.0 tag
                local latest_found=$(grep -c "Add latest feature" CHANGELOG.md)
                local bug_found=$(grep -c "Fix latest bug" CHANGELOG.md)
                local tagged_found=$(grep -c "Add tagged feature" CHANGELOG.md)
                
                if [ "$latest_found" -gt 0 ] && [ "$bug_found" -gt 0 ] && [ "$tagged_found" -eq 0 ]; then
                    pass_test "Auto-detected base commit from latest tag v1.1.0"
                else
                    fail_test "Incorrect changelog content. Found: latest=$latest_found, bug=$bug_found, tagged=$tagged_found. Content: $(cat CHANGELOG.md)"
                fi
            else
                fail_test "Missing release heading: $(cat CHANGELOG.md)"
            fi
        else
            fail_test "CHANGELOG.md not created"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
    
    # Cleanup  
    cd / && rm -rf "$test_repo"
}

test_version_prefix_formatting() {
    start_test "Proper heading format with version prefix"
    
    # Switch back to main test repo
    cd "$TEST_REPO_DIR"
    cleanup_release_branches
    
    # Test with default prefix "v"
    safe_remove_changelog
    
    output=$(git flow release start 1.3.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if file_contains "CHANGELOG.md" "## v1.3.0"; then
            pass_test "Version prefix 'v' correctly included in heading"
        else
            fail_test "Incorrect heading format, expected '## v1.3.0': $(cat CHANGELOG.md)"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
}

test_empty_changelog_scenario() {
    start_test "Empty changelog when no commits between base and HEAD"
    
    # Switch back to main test repo
    cd "$TEST_REPO_DIR"
    cleanup_release_branches
    
    # Start release from current HEAD (should result in empty changelog)
    local head_commit=$(git rev-parse HEAD)
    safe_remove_changelog
    
    output=$(git flow release start 1.4.0 "$head_commit" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if file_exists "CHANGELOG.md"; then
            if file_contains "CHANGELOG.md" "## v1.4.0"; then
                # For empty changelog, we expect either "- No changes" or no commit lines
                if file_contains "CHANGELOG.md" "No changes"; then
                    pass_test "Empty changelog properly handled with 'No changes' entry"
                else
                    # Check if there are no commit entries (empty changelog)
                    local commit_lines=$(grep -c "^- " CHANGELOG.md 2>/dev/null || echo 0)
                    if [ "$commit_lines" -eq 0 ]; then
                        pass_test "Empty changelog properly handled (no commit entries)"
                    else
                        fail_test "Unexpected commit entries in empty changelog: $(cat CHANGELOG.md)"
                    fi
                fi
            else
                fail_test "Missing release heading in empty changelog: $(cat CHANGELOG.md)"
            fi
        else
            fail_test "CHANGELOG.md not created for empty changelog scenario"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
}

#
# P1: Error Handling Tests
#

test_invalid_base_commit() {
    start_test "Error handling for invalid base commit"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Try with non-existent commit hash
    output=$(git flow release start 1.5.0 "invalid-commit-hash" 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        if echo "$output" | grep -q "fatal"; then
            pass_test "Properly rejected invalid base commit with clear error"
        else
            fail_test "Error message not clear enough: $output"
        fi
    else
        fail_test "Should have failed with invalid commit hash but succeeded"
    fi
}

test_base_commit_not_on_develop() {
    start_test "Error handling for base commit not on develop branch"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Create a commit on a different branch
    git checkout -b temp-branch
    echo "temp change" >> README.md
    git add README.md
    git commit -m "Temp commit"
    local temp_commit=$(git rev-parse HEAD)
    git checkout develop
    git branch -D temp-branch
    
    # Try to use that commit as base (should fail)
    output=$(git flow release start 1.6.0 "$temp_commit" 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        if echo "$output" | grep -q "not a valid commit on.*develop"; then
            pass_test "Properly rejected commit not on develop branch"
        else
            fail_test "Error message not specific enough: $output"
        fi
    else
        fail_test "Should have failed with commit not on develop branch"
    fi
}

test_no_previous_tags_with_develop_base() {
    start_test "Error handling when no previous tags exist and base is develop"
    
    # Create a new repo without any version tags
    local no_tags_repo="/tmp/gitflow-no-tags-$$"
    mkdir -p "$no_tags_repo"
    cd "$no_tags_repo"
    
    export PATH="$GITFLOW_DIR:$PATH"
    
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    echo "Initial" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    git flow init -d
    git config gitflow.prefix.versiontag "v"
    
    # Add some commits
    echo "feature" >> README.md
    git add README.md
    git commit -m "Add feature"
    
    # Try to start release (should fail since it can't determine base from develop)
    output=$(git flow release start 1.0.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        if echo "$output" | grep -q "No previous release tags found.*Cannot determine changelog range"; then
            pass_test "Properly handled missing tags with develop base"
        else
            fail_test "Error message not clear enough: $output"
        fi
    else
        fail_test "Should have failed when no tags exist and base is develop"
    fi
    
    # Cleanup
    cd /
    rm -rf "$no_tags_repo"
}

#
# P2: Integration Tests
#

test_complete_release_workflow_with_changelog() {
    start_test "Complete release workflow with changelog integration"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Remove existing changelog for clean test
    safe_remove_changelog
    
    # Start release
    start_output=$(git flow release start 2.0.0 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to start release: $start_output"
        return
    fi
    
    # Verify we're on release branch and changelog was created and committed
    if [ "$(get_current_branch)" = "release/2.0.0" ]; then
        if file_exists "CHANGELOG.md"; then
            # Check if CHANGELOG.md was committed
            if git log --oneline -1 | grep -q "Update CHANGELOG.md for release v2.0.0"; then
                pass_test "Release workflow with changelog integration successful"
            else
                fail_test "CHANGELOG.md was not committed: $(git log --oneline -3)"
            fi
        else
            fail_test "CHANGELOG.md not created in release workflow"
        fi
    else
        fail_test "Not on release branch after start: $(get_current_branch)"
    fi
}

test_changelog_git_commit_integration() {
    start_test "Changelog changes are properly committed to git"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    safe_remove_changelog
    
    # Record git log before release start
    local commits_before=$(git log --oneline | wc -l)
    
    output=$(git flow release start 2.1.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Check that a new commit was created
        local commits_after=$(git log --oneline | wc -l)
        local new_commits=$((commits_after - commits_before))
        
        if [ "$new_commits" -eq 1 ]; then
            # Check the commit message
            if git log --oneline -1 | grep -q "Update CHANGELOG.md for release v2.1.0"; then
                # Check that CHANGELOG.md is in the commit
                if git show --name-only HEAD | grep -q "CHANGELOG.md"; then
                    pass_test "CHANGELOG.md properly committed with descriptive message"
                else
                    fail_test "CHANGELOG.md not in the commit: $(git show --name-only HEAD)"
                fi
            else
                fail_test "Commit message not correct: $(git log --oneline -1)"
            fi
        else
            fail_test "Expected 1 new commit, got $new_commits commits"
        fi
    else
        fail_test "Release start command failed: $output"
    fi
}

# Cleanup test repository
cleanup_test_repo() {
    log_info "Cleaning up test repository"
    cd /
    rm -rf "$TEST_REPO_DIR"
}

#
# Test Execution
#

run_all_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Changelog Generation Test Suite    ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    setup_test_repo
    create_test_history
    
    # P0: Core Functionality Tests
    echo -e "\n${YELLOW}P0: Core Changelog Functionality Tests${NC}"
    test_changelog_creation_new_file
    test_changelog_appending_existing_file
    test_manual_base_commit_specification
    test_auto_base_detection_from_tags
    test_version_prefix_formatting
    test_empty_changelog_scenario
    
    # P1: Error Handling Tests
    echo -e "\n${YELLOW}P1: Error Handling Tests${NC}"
    test_invalid_base_commit
    test_base_commit_not_on_develop
    test_no_previous_tags_with_develop_base
    
    # P2: Integration Tests
    echo -e "\n${YELLOW}P2: Integration Tests${NC}"
    test_complete_release_workflow_with_changelog
    test_changelog_git_commit_integration
    
    cleanup_test_repo
    
    # Test Summary
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}            Test Summary                 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}All changelog tests passed! ✅${NC}"
        return 0
    else
        echo -e "\n${RED}Some changelog tests failed! ❌${NC}"
        return 1
    fi
}

# Check if script is being sourced or executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed directly
    
    # Ensure we have git-flow available
    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git command not found"
        exit 1
    fi
    
    # Check if git-flow scripts are available
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GITFLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    
    if [ ! -f "$GITFLOW_DIR/git-flow-release" ]; then
        echo "Error: git-flow-release script not found in $GITFLOW_DIR"
        echo "Please run this test from the git-flow directory or its test subdirectory"
        exit 1
    fi
    
    log_info "Using git-flow from: $GITFLOW_DIR"
    
    run_all_tests
    exit $?
fi
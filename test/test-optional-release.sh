#!/bin/bash
#
# Comprehensive Test Suite: Optional Release Argument Feature
# Tests the new functionality for git flow release start with optional version argument
#

# Test framework setup
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
TEST_REPO_DIR="/tmp/gitflow-test-$$"

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

# Setup test repository
setup_test_repo() {
    log_info "Setting up test repository at $TEST_REPO_DIR"
    
    # Clean up any existing test repo
    rm -rf "$TEST_REPO_DIR"
    mkdir -p "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"
    
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
    
    # Set version tag prefix to match our test tags
    git config gitflow.prefix.versiontag "v"
    
    # Create test version tags
    git tag v1.0.0
    git tag v1.2.3
    git tag v2.0.0
    
    # Add some non-semantic version tags to test filtering
    git tag v1.0 
    git tag release-1.0.0
    git tag v1.0.0-beta
    
    log_info "Test repository initialized with tags: $(git tag | tr '\n' ' ')"
}

# Cleanup test repository
cleanup_test_repo() {
    log_info "Cleaning up test repository"
    cd /
    rm -rf "$TEST_REPO_DIR"
}

# Helper function to check if branch exists
branch_exists() {
    git branch --list | grep -q " $1$"
}

# Helper function to get current branch
get_current_branch() {
    git branch --show-current
}

# Helper function to clean up release branches
cleanup_release_branches() {
    for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
        git branch -D "$branch" 2>/dev/null || true
    done
}

#
# P0: Core Functionality Tests
#

test_minor_version_bump() {
    start_test "Automatic minor version bump from latest tag"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Test command: git flow release start (should create v2.1.0 from v2.0.0)
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 2.1.0"; then
            if branch_exists "release/2.1.0"; then
                if [ "$(get_current_branch)" = "release/2.1.0" ]; then
                    pass_test "Minor version bump successful: v2.0.0 → 2.1.0"
                else
                    fail_test "Not switched to release branch, current: $(get_current_branch)"
                fi
            else
                fail_test "Release branch release/2.1.0 not created"
            fi
        else
            fail_test "Output missing auto-generation message: $output"
        fi
    else
        fail_test "Command failed with exit code $exit_code: $output"
    fi
}

test_major_version_bump() {
    start_test "Major version bump with --major flag"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Test command: git flow release start --major (should create v3.0.0 from v2.0.0)
    output=$(git flow release start --major 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 3.0.0"; then
            if branch_exists "release/3.0.0"; then
                if [ "$(get_current_branch)" = "release/3.0.0" ]; then
                    pass_test "Major version bump successful: v2.0.0 → 3.0.0"
                else
                    fail_test "Not switched to release branch, current: $(get_current_branch)"
                fi
            else
                fail_test "Release branch release/3.0.0 not created"
            fi
        else
            fail_test "Output missing auto-generation message: $output"
        fi
    else
        fail_test "Command failed with exit code $exit_code: $output"
    fi
}

test_explicit_version_compatibility() {
    start_test "Backward compatibility with explicit version"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Test command: git flow release start 1.5.0 (traditional behavior)
    output=$(git flow release start 1.5.0 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if branch_exists "release/1.5.0"; then
            if [ "$(get_current_branch)" = "release/1.5.0" ]; then
                # Should NOT have auto-generation message
                if ! echo "$output" | grep -q "Auto-generated version"; then
                    pass_test "Explicit version works correctly: 1.5.0"
                else
                    fail_test "Unexpected auto-generation message with explicit version"
                fi
            else
                fail_test "Not switched to release branch, current: $(get_current_branch)"
            fi
        else
            fail_test "Release branch release/1.5.0 not created"
        fi
    else
        fail_test "Command failed with exit code $exit_code: $output"
    fi
}

test_base_branch_with_auto_version() {
    start_test "Auto-version with explicit base branch"
    
    cleanup_release_branches
    cd "$TEST_REPO_DIR"
    
    # Create a feature branch to use as base
    git checkout -b feature/test
    echo "feature change" >> README.md
    git add README.md
    git commit -m "Feature change"
    git checkout develop
    
    # Test command: git flow release start --major feature/test
    output=$(git flow release start --major feature/test 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 3.0.0"; then
            if branch_exists "release/3.0.0"; then
                pass_test "Auto-version with explicit base branch successful"
            else
                fail_test "Release branch not created"
            fi
        else
            fail_test "Auto-generation failed with explicit base: $output"
        fi
    else
        fail_test "Command failed with exit code $exit_code: $output"
    fi
    
    # Cleanup
    git branch -D feature/test 2>/dev/null || true
}

#
# P1: Error Handling & Edge Cases
#

test_no_version_tags() {
    start_test "Error handling when no version tags exist"
    
    # Create a repo without version tags
    local no_tags_repo="/tmp/gitflow-no-tags-$$"
    mkdir -p "$no_tags_repo"
    cd "$no_tags_repo"
    
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    echo "Initial" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    git flow init -d
    
    # Test should fail with appropriate message
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        if echo "$output" | grep -q "No existing version tags found"; then
            pass_test "Appropriate error for missing version tags"
        else
            fail_test "Error message not clear enough: $output"
        fi
    else
        fail_test "Command should have failed but succeeded: $output"
    fi
    
    # Cleanup
    cd /
    rm -rf "$no_tags_repo"
}

test_non_semantic_tags_filtering() {
    start_test "Filtering non-semantic version tags"
    
    cd "$TEST_REPO_DIR"
    cleanup_release_branches
    
    # We already have non-semantic tags (v1.0, v1.0.0-beta, release-1.0.0)
    # The latest valid semantic version should still be v2.0.0
    
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 2.1.0"; then
            if echo "$output" | grep -q "based on latest tag: v2.0.0"; then
                pass_test "Correctly filtered non-semantic tags, used v2.0.0"
            else
                fail_test "Did not indicate correct base tag: $output"
            fi
        else
            fail_test "Did not generate expected version 2.1.0: $output"
        fi
    else
        fail_test "Command failed: $output"
    fi
}

test_existing_release_branch() {
    start_test "Error when release branch already exists"
    
    cd "$TEST_REPO_DIR"
    cleanup_release_branches
    
    # Create an existing release branch
    git checkout -b release/1.4.0
    git checkout develop
    
    # Try to create another release with auto-version
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        if echo "$output" | grep -q "existing release branch"; then
            pass_test "Correctly detected existing release branch"
        else
            fail_test "Error message not specific enough: $output"
        fi
    else
        fail_test "Should have failed due to existing release branch"
    fi
    
    # Cleanup
    git branch -D release/1.4.0 2>/dev/null || true
}

test_different_version_prefix() {
    start_test "Version detection with different prefix"
    
    cd "$TEST_REPO_DIR"
    cleanup_release_branches
    
    # Change version prefix
    git config gitflow.prefix.versiontag "release-"
    
    # Add tags with new prefix
    git tag release-3.0.0
    git tag release-3.1.0
    
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 3.2.0"; then
            if echo "$output" | grep -q "based on latest tag: release-3.1.0"; then
                pass_test "Correctly handled different version prefix"
            else
                fail_test "Did not use correct base tag: $output"
            fi
        else
            fail_test "Did not generate expected version: $output"
        fi
    else
        fail_test "Command failed with different prefix: $output"
    fi
    
    # Restore original prefix
    git config gitflow.prefix.versiontag "v"
}

#
# P2: Integration Tests
#

test_complete_release_lifecycle() {
    start_test "Complete release lifecycle with auto-generated version"
    
    cd "$TEST_REPO_DIR"
    cleanup_release_branches
    
    # Start release with auto-version
    start_output=$(git flow release start 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to start release: $start_output"
        return
    fi
    
    # Make a change in the release branch
    echo "Release change" >> README.md
    git add README.md
    git commit -m "Release change"
    
    # Extract version from start output
    version=$(echo "$start_output" | grep "Auto-generated version:" | sed 's/.*Auto-generated version: \([0-9.]*\).*/\1/')
    
    if [ -z "$version" ]; then
        fail_test "Could not extract version from start output"
        return
    fi
    
    # Finish the release
    finish_output=$(git flow release finish -m "Release $version" "$version" 2>&1)
    if [ $? -eq 0 ]; then
        # Check if tag was created
        if git tag --list | grep -q "v$version"; then
            pass_test "Complete lifecycle successful, tag v$version created"
        else
            fail_test "Release tag not created: $(git tag --list | grep v)"
        fi
    else
        fail_test "Failed to finish release: $finish_output"
    fi
}

test_help_documentation() {
    start_test "Help text includes --major flag"
    
    cd "$TEST_REPO_DIR"
    
    help_output=$(git flow release help 2>&1)
    
    if echo "$help_output" | grep -q -- "--major"; then
        if echo "$help_output" | grep -q "git flow release start.*\[<version>\]"; then
            pass_test "Help text properly documents optional version and --major flag"
        else
            fail_test "Help text doesn't show optional version syntax"
        fi
    else
        fail_test "Help text missing --major flag documentation"
    fi
}

#
# Test Execution
#

run_all_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Optional Release Argument Test Suite  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    setup_test_repo
    
    # P0: Core Functionality Tests
    echo -e "\n${YELLOW}P0: Core Functionality Tests${NC}"
    test_minor_version_bump
    test_major_version_bump
    test_explicit_version_compatibility
    test_base_branch_with_auto_version
    
    # P1: Error Handling & Edge Cases
    echo -e "\n${YELLOW}P1: Error Handling & Edge Cases${NC}"
    test_no_version_tags
    test_non_semantic_tags_filtering
    test_existing_release_branch
    test_different_version_prefix
    
    # P2: Integration Tests
    echo -e "\n${YELLOW}P2: Integration Tests${NC}"
    test_complete_release_lifecycle
    test_help_documentation
    
    cleanup_test_repo
    
    # Test Summary
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}            Test Summary                 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed! ✅${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed! ❌${NC}"
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
    
    # Check if git flow is available (try to source the git-flow-release script)
    if [ ! -f "$(dirname "$0")/git-flow-release" ]; then
        echo "Error: git-flow-release script not found in $(dirname "$0")"
        echo "Please run this test from the git-flow directory"
        exit 1
    fi
    
    # Add git-flow to PATH for testing
    export PATH="$(dirname "$0"):$PATH"
    
    run_all_tests
    exit $?
fi